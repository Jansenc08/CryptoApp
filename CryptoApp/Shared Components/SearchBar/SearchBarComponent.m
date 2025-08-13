
#import "SearchBarComponent.h"

@interface SearchBarComponent () <UISearchBarDelegate>
@property (nonatomic, strong, readwrite) UISearchBar *searchBar;
@end

@implementation SearchBarComponent

- (instancetype)initWithPlaceholder:(nullable NSString *)placeholder {
    return [self initWithPlaceholder:placeholder style:UISearchBarStyleMinimal];
}

- (instancetype)initWithPlaceholder:(nullable NSString *)placeholder style:(UISearchBarStyle)style {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _searchBarStyle = style;
        _automaticallyShowsCancelButton = YES;
        [self setupSearchBarWithPlaceholder:placeholder];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithPlaceholder:nil style:UISearchBarStyleMinimal];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _searchBarStyle = UISearchBarStyleMinimal;
        _automaticallyShowsCancelButton = YES;
        [self setupSearchBarWithPlaceholder:nil];
    }
    return self;
}

- (void)setupSearchBarWithPlaceholder:(nullable NSString *)placeholder {
    // Create search bar
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Configure appearance
    self.searchBar.searchBarStyle = self.searchBarStyle;
    self.searchBar.placeholder = placeholder ?: @"Search...";
    self.searchBar.tintColor = self.tintColor ?: UIColor.systemBlueColor;
    self.searchBar.backgroundColor = UIColor.clearColor;
    
    // Add to view
    [self addSubview:self.searchBar];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.searchBar.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

#pragma mark - Public Methods

- (void)becomeFirstResponder {
    [self.searchBar becomeFirstResponder];
}

- (void)resignFirstResponder {
    [self.searchBar resignFirstResponder];
}

- (void)setShowsCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated {
    _showsCancelButton = showsCancelButton;
    [self.searchBar setShowsCancelButton:showsCancelButton animated:animated];
}

- (void)clearText {
    self.searchBar.text = @"";
    if ([self.delegate respondsToSelector:@selector(searchBarComponent:textDidChange:)]) {
        [self.delegate searchBarComponent:self textDidChange:@""];
    }
}

#pragma mark - Configuration Methods

- (void)configureForFullScreenSearch {
    // Configuration for SearchVC - full screen search experience
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.tintColor = UIColor.systemBlueColor;
    self.searchBar.placeholder = @"Search cryptocurrencies...";
    self.automaticallyShowsCancelButton = YES;
    
    // Enable search results
    self.searchBar.showsSearchResultsButton = NO;
    self.searchBar.showsBookmarkButton = NO;
}

- (void)configureForInlineSearch {
    // Configuration for AddCoinsVC - inline search within a view
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.tintColor = UIColor.systemBlueColor;
    self.searchBar.placeholder = @"Search coins to add...";
    self.automaticallyShowsCancelButton = YES;
    
    // Simpler appearance for inline usage
    self.searchBar.showsSearchResultsButton = NO;
    self.searchBar.showsBookmarkButton = NO;
}

#pragma mark - Properties

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    self.searchBar.placeholder = placeholder;
}

- (NSString *)text {
    return self.searchBar.text;
}

- (void)setText:(NSString *)text {
    self.searchBar.text = text;
}

- (BOOL)showsCancelButton {
    return self.searchBar.showsCancelButton;
}

- (void)setTintColor:(UIColor *)tintColor {
    _tintColor = tintColor;
    self.searchBar.tintColor = tintColor;
}

- (void)setSearchBarStyle:(UISearchBarStyle)searchBarStyle {
    _searchBarStyle = searchBarStyle;
    self.searchBar.searchBarStyle = searchBarStyle;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self.delegate respondsToSelector:@selector(searchBarComponent:textDidChange:)]) {
        [self.delegate searchBarComponent:self textDidChange:searchText];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    if (self.automaticallyShowsCancelButton) {
        [self setShowsCancelButton:YES animated:YES];
    }
    
    if ([self.delegate respondsToSelector:@selector(searchBarComponentDidBeginEditing:)]) {
        [self.delegate searchBarComponentDidBeginEditing:self];
    }
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    if ([self.delegate respondsToSelector:@selector(searchBarComponentDidEndEditing:)]) {
        [self.delegate searchBarComponentDidEndEditing:self];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    if ([self.delegate respondsToSelector:@selector(searchBarComponentSearchButtonClicked:)]) {
        [self.delegate searchBarComponentSearchButtonClicked:self];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [self clearText];
    [searchBar resignFirstResponder];
    [self setShowsCancelButton:NO animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(searchBarComponentCancelButtonClicked:)]) {
        [self.delegate searchBarComponentCancelButtonClicked:self];
    }
}

- (void)dealloc {
    // Clean up delegate reference and search bar delegate
    self.delegate = nil;
    self.searchBar.delegate = nil;
}

@end 
