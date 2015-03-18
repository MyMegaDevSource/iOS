/**
 * @file CloudDriveTableViewController.m
 * @brief Cloud drive table view controller of the app.
 *
 * (c) 2013-2014 by Mega Limited, Auckland, New Zealand
 *
 * This file is part of the MEGA SDK - Client Access Engine.
 *
 * Applications using the MEGA API must present a valid application key
 * and comply with the the rules set forth in the Terms of Service.
 *
 * The MEGA SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * @copyright Simplified (2-clause) BSD License.
 *
 * You should have received a copy of the license along with this
 * program.
 */

#import "CloudDriveTableViewController.h"
#import "NodeTableViewCell.h"
#import "SVProgressHUD.h"
#import "LoginViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DetailsNodeInfoViewController.h"
#import "Helper.h"
#import "MEGAPreview.h"
#import "BrowserViewController.h"

#import "CameraUploads.h"

@interface CloudDriveTableViewController () {
    UIAlertView *folderAlertView;
    UIAlertView *removeAlertView;
    UIAlertView *renameAlertView;
    
    NSInteger indexNodeSelected;
    NSUInteger remainingOperations;
    
    NSMutableArray *exportLinks;
    
    NSMutableArray *matchSearchNodes;
    
    BOOL allNodesSelected;
    BOOL isSwipeEditing;
}

@property (weak, nonatomic) IBOutlet UIBarButtonItem *addBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *downloadBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *moveBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *renameBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteBarButtonItem;

@property (nonatomic, strong) MEGANodeList *nodes;

@property (nonatomic, strong) NSMutableArray *cloudImages;
@property (nonatomic, strong) NSMutableArray *selectedNodesArray;

@property (nonatomic) UIImagePickerController *imagePickerController;

@end

@implementation CloudDriveTableViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!self.user) {
        NSArray *buttonsItems = @[self.editButtonItem, self.addBarButtonItem];
        self.navigationItem.rightBarButtonItems = buttonsItems;
    } else {
        self.navigationItem.rightBarButtonItems = nil;
    }
    
    NSString *thumbsDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"thumbs"];
    NSError *error;
    if (![[NSFileManager defaultManager] fileExistsAtPath:thumbsDirectory]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:thumbsDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSLog(@"Create directory error: %@", error);
        }
    }
    
    NSString *previewsDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"previews"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:previewsDirectory]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:previewsDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSLog(@"Create directory error: %@", error);
        }
    }
    
    [self.searchDisplayController.searchResultsTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[MEGASdkManager sharedMEGASdk] addMEGADelegate:self];
    [[MEGASdkManager sharedMEGASdk] retryPendingConnections];
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.tableView.isEditing) {
        self.selectedNodesArray = nil;
        [self setEditing:NO animated:NO];
    }
    
    [[MEGASdkManager sharedMEGASdk] removeMEGADelegate:self];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [matchSearchNodes count];
    } else {
        return [[self.nodes size] integerValue];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"nodeCell";
    
    NodeTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    if (cell == nil) {
        cell = [[NodeTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    MEGANode *node = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    NSString *thumbnailFilePath = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"thumbs"];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
    
    if (!fileExists && [node hasThumbnail]) {
        [[MEGASdkManager sharedMEGASdk] getThumbnailNode:node destinationFilePath:thumbnailFilePath];
    }
    
    if (!fileExists) {
        if (isImage([[[node name] pathExtension] lowercaseString])) {
            [cell.thumbnailImageView setImage:[Helper defaultPhotoImage]];
        } else {
            [cell.thumbnailImageView setImage:[Helper imageForNode:node]];
        }
    } else {
        [cell.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
    }
    
    cell.nameLabel.text = [node name];
    
    if ([node type] == MEGANodeTypeFile) {
        struct tm *timeinfo;
        char buffer[80];
        
        time_t rawtime = [[node modificationTime] timeIntervalSince1970];
        timeinfo = localtime(&rawtime);
        
        strftime(buffer, 80, "%d/%m/%y %H:%M", timeinfo);
        
        NSString *date = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
        NSString *size = [NSByteCountFormatter stringFromByteCount:node.size.longLongValue  countStyle:NSByteCountFormatterCountStyleMemory];
        NSString *sizeAndDate = [NSString stringWithFormat:@"%@ • %@", size, date];
        
        cell.infoLabel.text = sizeAndDate;
    } else {
        NSInteger files = [[MEGASdkManager sharedMEGASdk] numberChildFilesForParent:node];
        NSInteger folders = [[MEGASdkManager sharedMEGASdk] numberChildFoldersForParent:node];
        
        NSString *filesAndFolders;
        
        if (files == 0 || files > 1) {
            if (folders == 0 || folders > 1) {
                filesAndFolders = [NSString stringWithFormat:NSLocalizedString(@"foldersFiles", @"Folders, files"), (int)folders, (int)files];
            } else if (folders == 1) {
                filesAndFolders = [NSString stringWithFormat:NSLocalizedString(@"folderFiles", @"Folder, files"), (int)folders, (int)files];
            }
        } else if (files == 1) {
            if (folders == 0 || folders > 1) {
                filesAndFolders = [NSString stringWithFormat:NSLocalizedString(@"foldersFile", @"Folders, file"), (int)folders, (int)files];
            } else if (folders == 1) {
                filesAndFolders = [NSString stringWithFormat:NSLocalizedString(@"folderFile", @"Folders, file"), (int)folders, (int)files];
            }
        }
        
        cell.infoLabel.text = filesAndFolders;
    }
    
    cell.nodeHandle = [node handle];
    
    if (self.isEditing) {
        // Check if selectedNodesArray contains the current node in the tableView
        for (MEGANode *n in self.selectedNodesArray) {
            if ([n handle] == [node handle]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    if (tableView.isEditing) {
        [self.selectedNodesArray addObject:node];
        
        [self.downloadBarButtonItem setEnabled:YES];
        [self.shareBarButtonItem setEnabled:YES];
        [self.moveBarButtonItem setEnabled:YES];
        [self.deleteBarButtonItem setEnabled:YES];
        
        if (self.selectedNodesArray.count == 1) {
            [self.renameBarButtonItem setEnabled:YES];
        } else {
            [self.renameBarButtonItem setEnabled:NO];
        }
        
        if (self.selectedNodesArray.count == self.nodes.size.integerValue) {
            allNodesSelected = YES;
            self.selectAllBarButtonItem.image = [UIImage imageNamed:@"deselectAll"];
        } else {
            allNodesSelected = NO;
            self.selectAllBarButtonItem.image = [UIImage imageNamed:@"selectAll"];
        }
        
        return;
    }
    
    switch ([node type]) {
        case MEGANodeTypeFolder: {
            if ([node.name isEqualToString:@"Camera Uploads"]) {
                [self.tabBarController setSelectedIndex:1];
            } else {
                CloudDriveTableViewController *cdvc = [self.storyboard instantiateViewControllerWithIdentifier:@"CloudDriveID"];
                [cdvc setParentNode:node];
                [self.navigationController pushViewController:cdvc animated:YES];
            }
            break;
        }
            
        case MEGANodeTypeFile: {
            NSString *name = [node name];
            if (isImage(name.lowercaseString.pathExtension)) {
                
                int offsetIndex = 0;
                self.cloudImages = [NSMutableArray new];
                
                if (tableView == self.searchDisplayController.searchResultsTableView) {
                    for (NSInteger i = 0; i < matchSearchNodes.count; i++) {
                        MEGANode *n = [matchSearchNodes objectAtIndex:i];
                        
                        if (isImage([n name].lowercaseString.pathExtension)) {
                            MEGAPreview *photo = [MEGAPreview photoWithNode:n];
                            photo.caption = [n name];
                            [self.cloudImages addObject:photo];
                            if ([n handle] == [node handle]) {
                                offsetIndex = (int)[self.cloudImages count] - 1;
                            }
                        }
                    }
                } else {
                    for (NSInteger i = 0; i < [[self.nodes size] integerValue]; i++) {
                        MEGANode *n = [self.nodes nodeAtIndex:i];
                        
                        if (isImage([n name].lowercaseString.pathExtension)) {
                            MEGAPreview *photo = [MEGAPreview photoWithNode:n];
                            photo.caption = [n name];
                            [self.cloudImages addObject:photo];
                            if ([n handle] == [node handle]) {
                                offsetIndex = (int)[self.cloudImages count] - 1;
                            }
                        }
                    }
                }
                
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                
                browser.displayActionButton = YES;
                browser.displayNavArrows = YES;
                browser.displaySelectionButtons = NO;
                browser.zoomPhotosToFill = YES;
                browser.alwaysShowControls = NO;
                browser.enableGrid = YES;
                browser.startOnGrid = NO;
                
                // Optionally set the current visible photo before displaying
                //    [browser setCurrentPhotoIndex:1];
                
                [self.navigationController pushViewController:browser animated:YES];
                
                [browser showNextPhotoAnimated:YES];
                [browser showPreviousPhotoAnimated:YES];
                [browser setCurrentPhotoIndex:offsetIndex];
            }
            break;
        }
            
        default:
            break;
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = [self.nodes nodeAtIndex:indexPath.row];
    
    if (tableView.isEditing) {
        
        //tempArray avoid crash: "was mutated while being enumerated."
        NSMutableArray *tempArray = [self.selectedNodesArray copy];
        for (MEGANode *n in tempArray) {
            if (n.handle == node.handle) {
                [self.selectedNodesArray removeObject:n];
            }
        }
        
        if (self.selectedNodesArray.count == 0) {
            [self.downloadBarButtonItem setEnabled:NO];
            [self.shareBarButtonItem setEnabled:NO];
            [self.moveBarButtonItem setEnabled:NO];
            [self.renameBarButtonItem setEnabled:NO];
            [self.deleteBarButtonItem setEnabled:NO];
        } else if (self.selectedNodesArray.count == 1) {
            [self.renameBarButtonItem setEnabled:YES];
        }
        
        allNodesSelected = NO;
        self.selectAllBarButtonItem.image = [UIImage imageNamed:@"selectAll"];
        
        return;
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    MEGANode *node = nil;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        node = [matchSearchNodes objectAtIndex:indexPath.row];
    } else {
        node = [self.nodes nodeAtIndex:indexPath.row];
    }
    
    DetailsNodeInfoViewController *nodeInfoDetailsVC = [self.storyboard instantiateViewControllerWithIdentifier:@"nodeInfoDetails"];
    [nodeInfoDetailsVC setNode:node];
    [self.navigationController pushViewController:nodeInfoDetailsVC animated:YES];
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGANode *n = [self.nodes nodeAtIndex:indexPath.row];
    
    self.selectedNodesArray = [NSMutableArray new];
    [self.selectedNodesArray addObject:n];
    
    [self.downloadBarButtonItem setEnabled:YES];
    [self.shareBarButtonItem setEnabled:YES];
    [self.moveBarButtonItem setEnabled:YES];
    [self.renameBarButtonItem setEnabled:YES];
    [self.deleteBarButtonItem setEnabled:YES];
    
    isSwipeEditing = YES;
    
    return (UITableViewCellEditingStyleDelete);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle==UITableViewCellEditingStyleDelete) {
        MEGANode *node = [self.nodes nodeAtIndex:indexPath.row];
        remainingOperations = 1;
        [[MEGASdkManager sharedMEGASdk] moveNode:node newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending)) {
        return 44.0;
    }
    else {
        return UITableViewAutomaticDimension;
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending)) {
        return 44.0;
    }
    else {
        return UITableViewAutomaticDimension;
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    if (editing) {
        [self.addBarButtonItem setEnabled:NO];
        if (!isSwipeEditing) {
            self.navigationItem.leftBarButtonItems = @[self.selectAllBarButtonItem];
        }
    } else {
        allNodesSelected = NO;
        self.selectAllBarButtonItem.image = [UIImage imageNamed:@"selectAll"];
        self.selectedNodesArray = nil;
        [self.addBarButtonItem setEnabled:YES];
        self.navigationItem.leftBarButtonItems = @[];
    }
    
    if (!self.selectedNodesArray) {
        self.selectedNodesArray = [NSMutableArray new];
        
        [self.downloadBarButtonItem setEnabled:NO];
        [self.shareBarButtonItem setEnabled:NO];
        [self.moveBarButtonItem setEnabled:NO];
        [self.renameBarButtonItem setEnabled:NO];
        [self.deleteBarButtonItem setEnabled:NO];
    }
    
    [self.tabBarController.tabBar addSubview:self.toolbar];
    
    [UIView animateWithDuration:animated ? .33 : 0 animations:^{
        self.toolbar.frame = CGRectMake(0, editing ? 0 : 49 , CGRectGetWidth(self.view.frame), 49);
    }];
    
    isSwipeEditing = NO;
}

#pragma mark - MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.cloudImages.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.cloudImages.count) {
        return [self.cloudImages objectAtIndex:index];
    }
    
    return nil;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        folderAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"newFolderTitle", @"Create new folder") message:NSLocalizedString(@"newFolderMessage", @"Name for the new folder") delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel") otherButtonTitles:NSLocalizedString(@"createFolderButton", @"Create"), nil];
        [folderAlertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
        [folderAlertView textFieldAtIndex:0].text = @"";
        folderAlertView.tag = 1;
        [folderAlertView show];
    } else if (buttonIndex == 1) {
        [self showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    }
}

#pragma mark - UIAlertDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 0){
        if (buttonIndex == 1) {
            if ([[[[self.selectedNodesArray objectAtIndex:0] name] pathExtension] isEqualToString:@""]) {
                [[MEGASdkManager sharedMEGASdk] renameNode:[self.selectedNodesArray objectAtIndex:0] newName:[alertView textFieldAtIndex:0].text];
            } else {
                NSString *newName = [[alertView textFieldAtIndex:0].text stringByAppendingFormat:@".%@", [[[self.selectedNodesArray objectAtIndex:0] name] pathExtension]];
                self.title = newName;
                [[MEGASdkManager sharedMEGASdk] renameNode:[self.selectedNodesArray objectAtIndex:0] newName:newName];
            }
        }
    }
    
    if (alertView.tag == 1) {
        if (buttonIndex == 1) {
            [[MEGASdkManager sharedMEGASdk] createFolderWithName:[[folderAlertView textFieldAtIndex:0] text] parent:self.parentNode];
        }
    }
    
    if (alertView.tag == 2) {
        if (buttonIndex == 1) {
            remainingOperations = self.selectedNodesArray.count;
            for (NSInteger i = 0; i < self.selectedNodesArray.count; i++) {
                [[MEGASdkManager sharedMEGASdk] moveNode:[self.selectedNodesArray objectAtIndex:i] newParent:[[MEGASdkManager sharedMEGASdk] rubbishNode]];
            }
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSURL *assetURL = [info objectForKey:UIImagePickerControllerReferenceURL];
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:assetURL resultBlock:^(ALAsset *asset)  {
        NSString *name = asset.defaultRepresentation.filename;
        NSDate *modificationTime = [asset valueForProperty:ALAssetPropertyDate];
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.image= [info objectForKey:@"UIImagePickerControllerOriginalImage"];
        NSData *webData = UIImageJPEGRepresentation(imageView.image, 0.9);
        
        
        NSString *localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
        [webData writeToFile:localFilePath atomically:YES];
        
        NSError *error = nil;
        NSDictionary *attributesDictionary = [NSDictionary dictionaryWithObject:modificationTime forKey:NSFileModificationDate];
        [[NSFileManager defaultManager] setAttributes:attributesDictionary ofItemAtPath:localFilePath error:&error];
        if (error) {
            NSLog(@"Error change modification date of file %@", error);
        }
        
        [[MEGASdkManager sharedMEGASdk] startUploadWithLocalPath:localFilePath parent:self.parentNode];
    } failureBlock:nil];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    self.imagePickerController = nil;
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Private methods

- (void)reloadUI {
    
    if (self.user) {
        self.nodes = [[MEGASdkManager sharedMEGASdk] inSharesForUser:self.user];
        [self.searchDisplayController.searchBar setFrame:CGRectMake(0, 0, 0, 0)];
    } else {
        if (!self.parentNode) {
            self.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
        }
        if ([[self.parentNode name] isEqualToString:@"CRYPTO_ERROR"]) {
            [self.navigationItem setTitle:NSLocalizedString(@"cloudDrive", @"Cloud drive")];
        } else {
            [self.navigationItem setTitle:[self.parentNode name]];
        }
        
        self.nodes = [[MEGASdkManager sharedMEGASdk] childrenForParent:self.parentNode];
    }
    
    [self.tableView reloadData];
}

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType {
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.sourceType = sourceType;
    imagePickerController.delegate = self;
    
    self.imagePickerController = imagePickerController;
    [self.tabBarController presentViewController:self.imagePickerController animated:YES completion:nil];
}

#pragma mark - IBActions

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    [self.selectedNodesArray removeAllObjects];
    
    if (!allNodesSelected) {
        MEGANode *n = nil;
        NSInteger nodeListSize = [[self.nodes size] integerValue];
        
        for (NSInteger i = 0; i < nodeListSize; i++) {
            n = [self.nodes nodeAtIndex:i];
            [self.selectedNodesArray addObject:n];
        }
        
        allNodesSelected = YES;
        self.selectAllBarButtonItem.image = [UIImage imageNamed:@"deselectAll"];
    } else {
        allNodesSelected = NO;
        self.selectAllBarButtonItem.image = [UIImage imageNamed:@"selectAll"];
    }
    
    if (self.selectedNodesArray.count == 0) {
        [self.downloadBarButtonItem setEnabled:NO];
        [self.shareBarButtonItem setEnabled:NO];
        [self.moveBarButtonItem setEnabled:NO];
        [self.deleteBarButtonItem setEnabled:NO];
        [self.renameBarButtonItem setEnabled:NO];
        
    } else if (self.selectedNodesArray.count >= 1 ) {
        [self.downloadBarButtonItem setEnabled:YES];
        [self.shareBarButtonItem setEnabled:YES];
        [self.moveBarButtonItem setEnabled:YES];
        [self.deleteBarButtonItem setEnabled:YES];
        
        if (self.selectedNodesArray.count == 1) {
            [self.renameBarButtonItem setEnabled:YES];
        } else {
            [self.renameBarButtonItem setEnabled:NO];
        }
    }
    
    [self.tableView reloadData];
}

- (IBAction)optionAdd:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel")
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:NSLocalizedString(@"createFolder", @"Create folder"), NSLocalizedString(@"uploadPhoto", @"Upload photo"), nil];
    [actionSheet showFromTabBar:self.tabBarController.tabBar];
}

- (IBAction)downloadAction:(UIBarButtonItem *)sender {
    for (MEGANode *n in self.selectedNodesArray) {
        if ([n type] == MEGANodeTypeFile) {
            [Helper downloadNode:n folder:@"" folderLink:NO];
        } else if ([n type] == MEGANodeTypeFolder) {
            NSString *folderName = [[[n base64Handle] stringByAppendingString:@"_"] stringByAppendingString:[[MEGASdkManager sharedMEGASdk] nameToLocal:[n name]]];
            NSString *folderPath = [[Helper pathForOffline] stringByAppendingPathComponent:folderName];
            
            if ([Helper createOfflineFolder:folderName folderPath:folderPath]) {
                [Helper downloadNodesOnFolder:folderPath parentNode:n folderLink:NO];
            }
        }
    }
    [self setEditing:NO animated:NO];
    [self.tabBarController setSelectedIndex:2]; //0 = Cloud, 1 = Photos, 2 = Offline, 3 = Contacts, 4 = Settings
}

- (IBAction)shareLinkAction:(UIBarButtonItem *)sender {
    exportLinks = [NSMutableArray new];
    remainingOperations = self.selectedNodesArray.count;
    
    for (MEGANode *n in self.selectedNodesArray) {
        [[MEGASdkManager sharedMEGASdk] exportNode:n];
    }
}

- (IBAction)moveCopyAction:(UIBarButtonItem *)sender {
    UINavigationController *mcnc = [self.storyboard instantiateViewControllerWithIdentifier:@"moveNodeNav"];
    [self presentViewController:mcnc animated:YES completion:nil];
    
    BrowserViewController *mcnvc = mcnc.viewControllers.firstObject;
    mcnvc.parentNode = [[MEGASdkManager sharedMEGASdk] rootNode];
    mcnvc.selectedNodesArray = [NSArray arrayWithArray:self.selectedNodesArray];
}

- (IBAction)deleteAction:(UIBarButtonItem *)sender {
    NSString *message = (self.selectedNodesArray.count > 1) ? [NSString stringWithFormat:NSLocalizedString(@"moveMultipleNodesToRubbishBinMessage", nil), self.selectedNodesArray.count] :[NSString stringWithString:NSLocalizedString(@"moveNodeToRubbishBinMessage", nil)];
    
    removeAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"moveNodeToRubbishBinTitle", @"Remove node") message:message delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel") otherButtonTitles:NSLocalizedString(@"ok", @"OK"), nil];
    [removeAlertView show];
    removeAlertView.tag = 2;
    [removeAlertView show];
}

- (IBAction)renameAction:(UIBarButtonItem *)sender {
    renameAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"renameNodeTitle", @"Rename") message:NSLocalizedString(@"renameNodeMessage", @"Enter the new name") delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel") otherButtonTitles:NSLocalizedString(@"renameNodeButton", @"Rename"), nil];
    [renameAlertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [renameAlertView textFieldAtIndex:0].text = [[[[self.selectedNodesArray objectAtIndex:0] name] lastPathComponent] stringByDeletingPathExtension];
    renameAlertView.tag = 0;
    [renameAlertView show];
}

#pragma mark - Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    
    matchSearchNodes = [NSMutableArray new];
    MEGANodeList *allNodeList = nil;
    
    if([scope isEqualToString:@"Recursive"]) {
        allNodeList = [[MEGASdkManager sharedMEGASdk] nodeListSearchForNode:self.parentNode searchString:searchText recursive:YES];
    } else {
        allNodeList = [[MEGASdkManager sharedMEGASdk] nodeListSearchForNode:self.parentNode searchString:searchText recursive:NO];
    }
    
    for (NSInteger i = 0; i < [allNodeList.size integerValue]; i++) {
        MEGANode *n = [allNodeList nodeAtIndex:i];
        [matchSearchNodes addObject:n];
    }
    
}

#pragma mark - UISearchDisplayControllerDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    
    return YES;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
    switch ([request type]) {
        case MEGARequestTypeExport:
            [SVProgressHUD showWithStatus:NSLocalizedString(@"generateLink", @"Generate link...")];
            break;
            
        default:
            break;
    }
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        if ([error type] == MEGAErrorTypeApiEAccess) {
            if ([request type] == MEGARequestTypeCreateFolder || [request type] == MEGARequestTypeUpload) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"permissionTitle", nil) message:NSLocalizedString(@"permissionMessage", nil) delegate:self cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
                [alertView show];
            }
        }
        return;
    }
    
    switch ([request type]) {
        case MEGARequestTypeFetchNodes:
            [[CameraUploads syncManager] setTabBarController:[super tabBarController]];
            if ([CameraUploads syncManager].isCameraUploadsEnabled) {
                [[CameraUploads syncManager] getAllAssetsForUpload];
            }
            
            [SVProgressHUD dismiss];
            break;
            
        case MEGARequestTypeGetAttrFile: {
            for (NodeTableViewCell *ntvc in [self.tableView visibleCells]) {
                if ([request nodeHandle] == [ntvc nodeHandle]) {
                    MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[request nodeHandle]];
                    NSString *thumbnailFilePath = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"thumbs"];
                    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
                    if (fileExists) {
                        [ntvc.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
                    }
                }
            }
            
            for (NodeTableViewCell *ntvc in [self.searchDisplayController.searchResultsTableView visibleCells]) {
                if ([request nodeHandle] == [ntvc nodeHandle]) {
                    MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForHandle:[request nodeHandle]];
                    NSString *thumbnailFilePath = [Helper pathForNode:node searchPath:NSCachesDirectory directory:@"thumbs"];
                    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath];
                    if (fileExists) {
                        [ntvc.thumbnailImageView setImage:[UIImage imageWithContentsOfFile:thumbnailFilePath]];
                    }
                }
            }
            
            break;
        }
            
        case MEGARequestTypeMove: {
            remainingOperations--;
            if (remainingOperations == 0) {
                NSString *message = (self.selectedNodesArray.count <= 1 ) ? [NSString stringWithFormat:NSLocalizedString(@"fileMovedToRubbishBin", nil)] : [NSString stringWithFormat:NSLocalizedString(@"filesMovedToRubbishBin", nil), self.selectedNodesArray.count];
                [SVProgressHUD showSuccessWithStatus:message];
                [self setEditing:NO animated:NO];
            }
            break;
        }
            
        case MEGARequestTypeExport: {
            remainingOperations--;
            
            MEGANode *n = [[MEGASdkManager sharedMEGASdk] nodeForHandle:request.nodeHandle];
            
            NSString *name = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"fileName", nil), n.name];
            
            NSString *size = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"fileSize", nil), n.isFile ? [NSByteCountFormatter stringFromByteCount:[[n size] longLongValue]  countStyle:NSByteCountFormatterCountStyleMemory] : NSLocalizedString(@"folder", nil)];
            
            NSString *link = [request link];
            
            NSArray *tempArray = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ \n %@ \n %@\n", name, size, link], nil];
            [exportLinks addObjectsFromArray:tempArray];
            
            if (remainingOperations == 0) {
                [SVProgressHUD dismiss];
                UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:exportLinks applicationActivities:nil];
                activityVC.excludedActivityTypes = @[UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll];
                [self presentViewController:activityVC animated:YES completion:nil ];
                [self setEditing:NO animated:NO];
            }
            break;
        }
            
        default:
            break;
    }
}

- (void)onRequestTemporaryError:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
}

#pragma mark - MEGAGlobalDelegate

- (void)onReloadNeeded:(MEGASdk *)api {
}

- (void)onNodesUpdate:(MEGASdk *)api nodeList:(MEGANodeList *)nodeList {
    [self reloadUI];
}


#pragma mark - MEGATransferDelegate

- (void)onTransferStart:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
}

- (void)onTransferUpdate:(MEGASdk *)api transfer:(MEGATransfer *)transfer {
}

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
    if ([error type]) {
        if ([error type] == MEGAErrorTypeApiEAccess) {
            if ([transfer type] ==  MEGATransferTypeUpload) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"permissionTitle", nil) message:NSLocalizedString(@"permissionMessage", nil) delegate:self cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
                [alertView show];
            }
        }
        return;
    }
    
    if ([transfer type] == MEGATransferTypeUpload) {
        NSError *e = nil;
        NSString *localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[transfer fileName]];
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:localFilePath error:&e];
        if (!success || e) {
            NSLog(@"remove file error %@", e);
        }
    }
}

-(void)onTransferTemporaryError:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
}

@end