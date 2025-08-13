
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SearchBarComponent;

@protocol SearchBarComponentDelegate <NSObject>
@optional
- (void)searchBarComponent:(SearchBarComponent *)searchBar textDidChange:(NSString *)searchText;
- (void)searchBarComponentDidBeginEditing:(SearchBarComponent *)searchBar;
- (void)searchBarComponentDidEndEditing:(SearchBarComponent *)searchBar;
- (void)searchBarComponentSearchButtonClicked:(SearchBarComponent *)searchBar;
- (void)searchBarComponentCancelButtonClicked:(SearchBarComponent *)searchBar;
@end

@interface SearchBarComponent : UIView

@property (nonatomic, weak, nullable) id<SearchBarComponentDelegate> delegate;
@property (nonatomic, strong, readonly) UISearchBar *searchBar;
@property (nonatomic, strong, nullable) NSString *placeholder;
@property (nonatomic, strong, nullable) NSString *text;
@property (nonatomic, assign) BOOL showsCancelButton;

// Enhanced search bar appearance
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic, assign) UISearchBarStyle searchBarStyle;
@property (nonatomic, assign) BOOL automaticallyShowsCancelButton;

// Initialization
- (instancetype)initWithPlaceholder:(nullable NSString *)placeholder;
- (instancetype)initWithPlaceholder:(nullable NSString *)placeholder style:(UISearchBarStyle)style;

// Control methods
- (void)becomeFirstResponder;
- (void)resignFirstResponder;
- (void)setShowsCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated;
- (void)clearText;

// Configuration methods
- (void)configureForFullScreenSearch; // For SearchVC usage
- (void)configureForInlineSearch;     // For AddCoinsVC usage

@end

NS_ASSUME_NONNULL_END 
