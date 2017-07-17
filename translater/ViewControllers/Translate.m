//
//  Translate.m
//  translater
//
//  Created by sambo on 03.07.17.
//  Copyright © 2017 admin. All rights reserved.
//

#import "AppColors.h"
#import "LanguageSelecting.h"
#import "Translator.h"
#import "Translate.h"

typedef enum : NSUInteger {
    SelectionStatusNone,
    SelectionStatusLangFrom,
    SelectionStatusLangOn,
} SelectionStatus;

@interface Translate () <TranslatorDelegate, LanguageSelectingDelegate, UITextViewDelegate>

// view
@property (weak, nonatomic) IBOutlet UIButton *langFromButton;
@property (weak, nonatomic) IBOutlet UIButton *langOnButton;
@property (weak, nonatomic) IBOutlet UIButton *reverseLangsButton;
@property (weak, nonatomic) IBOutlet UITextView *inputTextView;
@property (weak, nonatomic) IBOutlet UITextView *outputTextView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (weak, nonatomic) IBOutlet UIButton *clearInputButton;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;
@property (weak, nonatomic) IBOutlet UITextView *copyrightText;
@property (weak, nonatomic) IBOutlet UILabel *inputPlaceholder;

// controls
@property (strong, nonatomic) NSString *selectedLangFrom;
@property (strong, nonatomic) NSString *selectedLangOn;
@property (strong, nonatomic) NSArray<NSString *> *allLanguages;
@property (assign, nonatomic) SelectionStatus selectionStatus;
@property (assign, nonatomic) BOOL isSpaceWasType;
@property (assign, nonatomic) BOOL isErrorOutput;
@property (assign, nonatomic) BOOL isInputEditing;

// models
@property (strong, nonatomic) TranslateEntity *translatingEntity;
@property (strong, nonatomic) Translator *translator;
@property (strong, nonatomic) NSTimer *updateTranslateTimer;

@end

@implementation Translate

static NSString *langSelectingSegueIdentifier = @"SelectLanguage";
static NSString *inputPlaceholder = @"Input text here...";
static NSString *langFromKey = @"LanguageFromSavedKey";
static NSString *langOnKey = @"LanguageOnSavedKey";

#pragma mark - Life Time

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UITabBar appearance] setUnselectedItemTintColor:[UIColor darkGrayColor]];
    [[UITabBar appearance] setTintColor:[AppColors secondColor]];
    
    // init view
    self.langFromButton.layer.cornerRadius = 5.0F;
    self.langFromButton.clipsToBounds = YES;
    self.langOnButton.layer.cornerRadius = 5.0F;
    self.langOnButton.clipsToBounds = YES;
    self.inputTextView.textContainerInset = UIEdgeInsetsMake(5, 5, 5, self.clearInputButton.frame.size.width);
    [self deactivateInputView];
    [self.loadingIndicator setHidden:FALSE];
    [self.reverseLangsButton setHidden:TRUE];
    [self.langFromButton setHidden:TRUE];
    [self.langOnButton setHidden:TRUE];
    [self.saveButton setHidden:TRUE];
    
    self.selectedLangFrom = [[NSUserDefaults standardUserDefaults] objectForKey:langFromKey];
    if (!self.selectedLangFrom) self.selectedLangFrom = @"Bulgarian";
    
    self.selectedLangOn = [[NSUserDefaults standardUserDefaults] objectForKey:langOnKey];
    if (!self.selectedLangOn) self.selectedLangOn = @"English";
    
    // tap and swipe for dismiss keyboard
    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    swipe.direction = UISwipeGestureRecognizerDirectionUp | UISwipeGestureRecognizerDirectionDown;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:swipe];
    [self.view addGestureRecognizer:tap];
    
    // translator initialize
    self.translator = [[Translator alloc] initWithDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    self.saveButton.selected = self.translatingEntity.isFavorite;
}

#pragma mark - Users Actions

- (IBAction)langFromAction:(id)sender {
    self.selectionStatus = SelectionStatusLangFrom;
    [self deactivateInputView];
    [self performSegueWithIdentifier:langSelectingSegueIdentifier sender:nil];
}

- (IBAction)langOnAction:(id)sender {
    self.selectionStatus = SelectionStatusLangOn;
    [self deactivateInputView];
    [self performSegueWithIdentifier:langSelectingSegueIdentifier sender:nil];
}

- (IBAction)reverseLangsAction:(id)sender {
    if (![_selectedLangFrom isEqualToString:_selectedLangOn]) {
        NSString *holder = _selectedLangFrom;
        self.selectedLangFrom = _selectedLangOn;
        self.selectedLangOn = holder;
        [self fullRefreshTranslate];
        self.saveButton.selected = FALSE;
    }
}

- (IBAction)clearInputAction:(id)sender {
    self.inputTextView.text = nil;
    if (!_isErrorOutput) {
        [self output:nil withError:nil];
    }
    [self.clearInputButton setHidden:!(self.isInputEditing)];
    [self.inputPlaceholder setHidden:(self.isInputEditing)];
    self.translatingEntity = nil;
    self.saveButton.selected = FALSE;
}

- (IBAction)saveAction:(id)sender {
    if (self.translatingEntity.isFavorite) {
        
        self.translatingEntity.isFavorite = FALSE;
        self.saveButton.selected = FALSE;
    } else {
        
        self.translatingEntity.isFavorite = TRUE;
        self.saveButton.selected = TRUE;
        [self.translator addTranslateHistory:self.translatingEntity];
    }
}

- (void)dismissKeyboard {
    [self.inputTextView resignFirstResponder];
    [self deactivateInputView];
    [self updateTranslate];
}

#pragma mark - UI changing

- (void)deactivateInputView {
    self.isInputEditing = FALSE;
    [self.clearInputButton setHidden:[_inputTextView.text isEqualToString:@""]];
}

- (void)activateInputView {
    self.isInputEditing = TRUE;
    [self.clearInputButton setHidden:FALSE];
}

- (void)output:(NSString*)text withError:(NSError*)error {
    
    if (error) {
        _isErrorOutput = TRUE;
        [self.saveButton setHidden:TRUE];
        self.outputTextView.text = error.localizedDescription;
        self.outputTextView.textColor = [UIColor redColor];
        self.outputTextView.textAlignment = NSTextAlignmentCenter;
        
    } else if (text) {
        _isErrorOutput = FALSE;
        [self.saveButton setHidden:FALSE];
        self.outputTextView.text = text;
        self.outputTextView.textColor = [UIColor darkGrayColor];
        self.outputTextView.textAlignment = NSTextAlignmentLeft;
        
    } else {
        [self.saveButton setHidden:TRUE];
        self.outputTextView.text = nil;
    }
}



#pragma mark - TranslateControls

- (void)fullRefreshTranslate {
    self.translatingEntity = [[TranslateEntity alloc] initWithLangFrom:_selectedLangFrom andLangOn:_selectedLangOn andInput:self.inputTextView.text];
    [self.translator translate:self.translatingEntity];
}

- (void)updateTranslate {
    if (self.translatingEntity) {
        self.translatingEntity.inputText = _inputTextView.text;
        [self.translator translate:self.translatingEntity];
    } else {
        [self fullRefreshTranslate];
    }
    
}

#pragma mark - Selected Languages Setters

- (void)setSelectedLangOn:(NSString *)selectedLangOn {
    
    if (![_selectedLangOn isEqualToString:selectedLangOn]) {
        _selectedLangOn = selectedLangOn;
        [[NSUserDefaults standardUserDefaults] setObject:selectedLangOn forKey:langOnKey];
        [self.langOnButton setTitle:selectedLangOn forState:UIControlStateNormal];
        [self fullRefreshTranslate];
    }
}

- (void)setSelectedLangFrom:(NSString *)selectedLangFrom {
    
    if (![_selectedLangFrom isEqualToString:selectedLangFrom]) {
        _selectedLangFrom = selectedLangFrom;
        [[NSUserDefaults standardUserDefaults] setObject:selectedLangFrom forKey:langFromKey];
        [self.langFromButton setTitle:selectedLangFrom forState:UIControlStateNormal];
        [self fullRefreshTranslate];
    }
}

#pragma mark - LanguageSelectingDelegate

- (void)receiveSelectedLanguage:(NSString *)language {
    
    if (_selectionStatus == SelectionStatusLangOn) {
        self.selectedLangOn = language;
        
    } else if (_selectionStatus == SelectionStatusLangFrom) {
        self.selectedLangFrom = language;
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self activateInputView];
    [self.inputPlaceholder setHidden:TRUE];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (![textView hasText]) {
        [self.inputPlaceholder setHidden:FALSE];
    }
}


- (void)textViewDidChange:(UITextView *)textView {
    
    if ([_inputTextView.text rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location == NSNotFound) {
        // didn't found any characters - clear outputtextView
        [self output:nil withError:nil];
        self.translatingEntity = nil;
        self.saveButton.selected = FALSE;
    } else {
        [self.updateTranslateTimer invalidate];
        self.updateTranslateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTranslate) userInfo:nil repeats:FALSE];
    }
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    if([text isEqualToString:@"\n"]) {
        [self dismissKeyboard];
        return NO;
        
    } else if ([text isEqualToString:@" "] && !self.isSpaceWasType) {
        self.isSpaceWasType = TRUE;
        [self updateTranslate];
        
    } else {
        self.isSpaceWasType = FALSE;
    }
    
    return YES;
}

#pragma mark - TranslatorDelegate

- (void)receiveLanguagesList:(NSArray<NSString *> *)allLanguages withError:(NSError *)error {
    
    if (error) {
        [self output:nil withError:error];
    } else {
        
        [self.loadingIndicator setHidden:TRUE];
        [self.reverseLangsButton setHidden:FALSE];
        [self.langFromButton setHidden:FALSE];
        [self.langOnButton setHidden:FALSE];
        
        self.allLanguages = allLanguages;
    }
}

- (void)receiveTranslate:(TranslateEntity *)translate withError:(NSError *)error {
    
    if (error) {
        [self output:nil withError:error];
    } else {
        
        if (self.translatingEntity == translate) { // link comparing
            [self output:translate.outputText withError:nil];
        }
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:langSelectingSegueIdentifier]) {
        
        LanguageSelecting *langSelecting = (LanguageSelecting*)[segue destinationViewController];
        langSelecting.delegate = self;
        [langSelecting selectLanguageFromList:self.allLanguages];
    }
}


@end





