/**
 * @file CreateAccountViewController.m
 * @brief View controller that allows to create an account on MEGA
 *
 * (c) 2013-2015 by Mega Limited, Auckland, New Zealand
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

#import "CreateAccountViewController.h"

#import "Helper.h"
#import "MEGAReachabilityManager.h"
#import "SVProgressHUD.h"
#import "SVModalWebViewController.h"

@interface CreateAccountViewController () <UINavigationControllerDelegate, UITextFieldDelegate, MEGARequestDelegate>

@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UITextField *retypePasswordTextField;

@property (weak, nonatomic) IBOutlet UIButton *termsCheckboxButton;
@property (weak, nonatomic) IBOutlet UIButton *termsOfServiceButton;

@property (weak, nonatomic) IBOutlet UIButton *createAccountButton;

@property (weak, nonatomic) IBOutlet UIView *accountCreatedView;
@property (weak, nonatomic) IBOutlet UILabel *accountCreatedTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *accountCreatedLabel;

@property (weak, nonatomic) IBOutlet UIButton *loginButton;

@end

@implementation CreateAccountViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.nameTextField setPlaceholder:AMLocalizedString(@"name", nil)];
    
    if (self.emailString == nil) {
        [_emailTextField setPlaceholder:AMLocalizedString(@"emailPlaceholder", nil)];
    } else {
        [_emailTextField setText:self.emailString];
    }
    
    [self.passwordTextField setPlaceholder:AMLocalizedString(@"passwordPlaceholder", @"Password")];
    [self.retypePasswordTextField setPlaceholder:AMLocalizedString(@"confirmPassword", nil)];
    
    [self.termsOfServiceButton setTitleColor:[UIColor mnz_redD90007] forState:UIControlStateNormal];
    [self.termsOfServiceButton setTitle:AMLocalizedString(@"termsOfServiceButton", @"I agree with the MEGA Terms of Service") forState:UIControlStateNormal];
    if (iPhone4X || iPhone5X) {
        [self.termsOfServiceButton.titleLabel setFont:[UIFont fontWithName:kFont size:11.0]];
    }
    
    self.createAccountButton.layer.cornerRadius = 4.0f;
    self.createAccountButton.layer.masksToBounds = YES;
    [self.createAccountButton setBackgroundColor:[UIColor mnz_redFF4C52]];
    [self.createAccountButton setTitle:AMLocalizedString(@"createAccount", @"Create Account") forState:UIControlStateNormal];
    
    [self.accountCreatedView.layer setMasksToBounds:YES];
    [self.accountCreatedTitleLabel setText:AMLocalizedString(@"awaitingEmailConfirmation", nil)];
    [self.accountCreatedLabel setText:AMLocalizedString(@"accountCreated", @"Please check your e-mail and click the link to confirm your account.")];
    
    [self.loginButton setTitle:AMLocalizedString(@"login", nil) forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController.navigationBar.topItem setTitle:AMLocalizedString(@"createAccount", @"Create Account")];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - Private methods

- (BOOL)validateForm {
    if (![self validateName:self.nameTextField.text]) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"nameInvalidFormat", @"Enter a valid name")];
        [self.nameTextField becomeFirstResponder];
        return NO;
    } else if (![self validateEmail:self.emailTextField.text]) {
        [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"emailInvalidFormat", @"Enter a valid email")];
        [self.emailTextField becomeFirstResponder];
        return NO;
    } else if (![self validatePassword:self.passwordTextField.text]) {
        if ([self.passwordTextField.text length] == 0) {
            [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"passwordInvalidFormat", @"Enter a valid password")];
            [self.passwordTextField becomeFirstResponder];
        } else {
            [SVProgressHUD showErrorWithStatus:AMLocalizedString(@"passwordsDoNotMatch", @"Passwords do not match")];
            [self.retypePasswordTextField becomeFirstResponder];
        }
        return NO;
    } else if (![self.termsCheckboxButton isSelected]) {
        [SVProgressHUD showImage:[UIImage imageNamed:@"hudWarning"] status:AMLocalizedString(@"termsCheckboxUnselected", nil)];
        return NO;
    }
    return YES;
}

- (BOOL)validateName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)validatePassword:(NSString *)password {
    if (password.length == 0 || ![password isEqualToString:self.retypePasswordTextField.text]) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)validateEmail:(NSString *)email {
    NSString *emailRegex =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
    
    return [emailTest evaluateWithObject:email];
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

#pragma mark - IBActions

- (IBAction)termsCheckboxTouchUpInside:(id)sender {
    self.termsCheckboxButton.selected = !self.termsCheckboxButton.selected;
    
    [self.nameTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
    [self.passwordTextField resignFirstResponder];
    [self.retypePasswordTextField resignFirstResponder];
}

- (IBAction)termOfServiceTouchUpInside:(UIButton *)sender {
    if ([MEGAReachabilityManager isReachableHUDIfNot]) {
        NSURL *URL = [NSURL URLWithString:@"https://mega.nz/ios_terms.html"];
        SVModalWebViewController *webViewController = [[SVModalWebViewController alloc] initWithURL:URL];
        [webViewController setBarsTintColor:[UIColor mnz_redD90007]];
        [self presentViewController:webViewController animated:YES completion:nil];
    }
}

- (IBAction)createAccountTouchUpInside:(id)sender {
    if ([self validateForm]) {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            [SVProgressHUD show];
            [[MEGASdkManager sharedMEGASdk] createAccountWithEmail:[self.emailTextField text] password:[self.passwordTextField text] firstname:[self.nameTextField text] lastname:NULL delegate:self];
            [self.createAccountButton setEnabled:NO];
        }
    }
}

#pragma mark - UITextFieldDelegate

-(BOOL)textFieldShouldReturn:(UITextField *)textField {

    switch ([textField tag]) {
        case 0:
            [self.emailTextField becomeFirstResponder];
            break;
            
        case 1:
            [self.passwordTextField becomeFirstResponder];
            break;
            
        case 2:
            [self.retypePasswordTextField becomeFirstResponder];
            break;
            
        case 3:
            [self.retypePasswordTextField resignFirstResponder];
            break;
            
        default:
            break;
    }
    
    return YES;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request {
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
    if ([error type]) {
        switch ([error type]) {
                
            case MEGAErrorTypeApiEExist: {
                [SVProgressHUD showImage:[UIImage imageNamed:@"hudWarning"] status:AMLocalizedString(@"emailAlreadyRegistered", nil)];
                [self.emailTextField becomeFirstResponder];
                
                [self.createAccountButton setEnabled:YES];
                break;
            }
                
            default:
                break;
        }
        return;
    }
    
    switch ([request type]) {
        case MEGARequestTypeCreateAccount: {
            [SVProgressHUD dismiss];
            
            [self.nameTextField setEnabled:NO];
            [self.emailTextField setEnabled:NO];
            [self.passwordTextField setEnabled:NO];
            [self.retypePasswordTextField setEnabled:NO];
            [self.termsCheckboxButton setUserInteractionEnabled:NO];
            [self.createAccountButton setEnabled:NO];
            
            [self.accountCreatedView setHidden:NO];
        }
            
        default:
            break;
    }
}

- (void)onRequestUpdate:(MEGASdk *)api request:(MEGARequest *)request {
}

- (void)onRequestTemporaryError:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error {
}


@end
