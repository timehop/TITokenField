//
//  TITokenField.m
//  TITokenField
//
//  Created by Tom Irving on 16/02/2010.
//  Copyright 2012 Tom Irving. All rights reserved.
//

#import "TITokenField.h"
#import <QuartzCore/QuartzCore.h>

//==========================================================
#pragma mark - TITokenFieldView -
//==========================================================

@interface TITokenFieldView (Private)
- (void)setup;
- (NSString *)displayStringForRepresentedObject:(id)object;
- (NSString *)searchResultStringForRepresentedObject:(id)object;
- (void)setSearchResultsVisible:(BOOL)visible;
- (void)resultsForSearchString:(NSString *)searchString;
- (void)presentpopoverAtTokenFieldCaretAnimated:(BOOL)animated;
@end

@implementation TITokenFieldView
@dynamic delegate;
@synthesize showAlreadyTokenized;
@synthesize tokenField;
@synthesize resultsTable;
@synthesize contentView;
@synthesize separator;
@synthesize sourceArray;

#pragma mark Init
- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])){
		[self setup];
	}
	
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	
	if ((self = [super initWithCoder:aDecoder])){
		[self setup];
	}
	
	return self;
}

- (void)setup {
	
	[self setBackgroundColor:[UIColor clearColor]];
	[self setDelaysContentTouches:YES];
	[self setMultipleTouchEnabled:NO];
	
	showAlreadyTokenized = NO;
	resultsArray = [[NSMutableArray alloc] init];
	
	tokenField = [[TITokenField alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 42)];
	[tokenField addTarget:self action:@selector(tokenFieldDidBeginEditing:) forControlEvents:UIControlEventEditingDidBegin];
	[tokenField addTarget:self action:@selector(tokenFieldDidEndEditing:) forControlEvents:UIControlEventEditingDidEnd];
	[tokenField addTarget:self action:@selector(tokenFieldTextDidChange:) forControlEvents:UIControlEventEditingChanged];
	[tokenField addTarget:self action:@selector(tokenFieldFrameWillChange:) forControlEvents:TITokenFieldControlEventFrameWillChange];
	[tokenField addTarget:self action:@selector(tokenFieldFrameDidChange:) forControlEvents:TITokenFieldControlEventFrameDidChange];
	[tokenField setDelegate:self];
	[self addSubview:tokenField];
	[tokenField release];
	
	CGFloat tokenFieldBottom = CGRectGetMaxY(tokenField.frame);
	
	separator = [[UIView alloc] initWithFrame:CGRectMake(0, tokenFieldBottom, self.bounds.size.width, 1)];
	[separator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:1]];
	[self addSubview:separator];
	[separator release];
	
	// This view is created for convenience, because it resizes and moves with the rest of the subviews.
	contentView = [[UIView alloc] initWithFrame:CGRectMake(0, tokenFieldBottom + 1, self.bounds.size.width,
														   self.bounds.size.height - tokenFieldBottom - 1)];
	[contentView setBackgroundColor:[UIColor clearColor]];
	[self addSubview:contentView];
	[contentView release];
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
		
		UITableViewController * tableViewController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
		[tableViewController.tableView setDelegate:self];
		[tableViewController.tableView setDataSource:self];
		[tableViewController setContentSizeForViewInPopover:CGSizeMake(400, 400)];
		
		resultsTable = tableViewController.tableView;
		
		popoverController = [[UIPopoverController alloc] initWithContentViewController:tableViewController];
		[tableViewController release];
	}
	else
	{
		resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(0, tokenFieldBottom + 1, self.bounds.size.width, 10)];
		[resultsTable setSeparatorColor:[UIColor colorWithWhite:0.85 alpha:1]];
		[resultsTable setBackgroundColor:[UIColor colorWithRed:0.92 green:0.92 blue:0.92 alpha:1]];
		[resultsTable setDelegate:self];
		[resultsTable setDataSource:self];
		[resultsTable setHidden:YES];
		[self addSubview:resultsTable];
		[resultsTable release];
		
		popoverController = nil;
	}
	
	[self bringSubviewToFront:separator];
	[self bringSubviewToFront:tokenField];
	[self updateContentSize];
}

#pragma mark Property Overrides
- (void)setFrame:(CGRect)frame {
	
	[super setFrame:frame];
	
	CGFloat width = frame.size.width;
	[separator setFrame:((CGRect){separator.frame.origin, {width, separator.bounds.size.height}})];
	[resultsTable setFrame:((CGRect){resultsTable.frame.origin, {width, resultsTable.bounds.size.height}})];
	[contentView setFrame:((CGRect){contentView.frame.origin, {width, (frame.size.height - CGRectGetMaxY(tokenField.frame))}})];
	[tokenField setFrame:((CGRect){tokenField.frame.origin, {width, tokenField.bounds.size.height}})];
	
	if (popoverController.popoverVisible){
		[popoverController dismissPopoverAnimated:NO];
		[self presentpopoverAtTokenFieldCaretAnimated:NO];
	}
	
	[self updateContentSize];
	[self layoutSubviews];
}

- (void)setContentOffset:(CGPoint)offset {
	[super setContentOffset:offset];
	[self layoutSubviews];
}

- (NSArray *)tokenTitles {
	return tokenField.tokenTitles;
}

#pragma mark Event Handling
- (void)layoutSubviews {
	
	[super layoutSubviews];
	
	CGFloat relativeFieldHeight = CGRectGetMaxY(tokenField.frame) - self.contentOffset.y;
	CGFloat newHeight = self.bounds.size.height - relativeFieldHeight;
	if (newHeight > -1) [resultsTable setFrame:((CGRect){resultsTable.frame.origin, {resultsTable.bounds.size.width, newHeight}})];
}

- (void)updateContentSize {
	[self setContentSize:CGSizeMake(self.bounds.size.width, CGRectGetMaxY(contentView.frame) + 1)];
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

- (BOOL)becomeFirstResponder {
	return [tokenField becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
	return [tokenField resignFirstResponder];
}

#pragma mark TableView Methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if ([tokenField.delegate respondsToSelector:@selector(tokenField:resultsTableView:heightForRowAtIndexPath:)]){
		return [tokenField.delegate tokenField:tokenField resultsTableView:tableView heightForRowAtIndexPath:indexPath];
	}
	
	return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	if ([tokenField.delegate respondsToSelector:@selector(tokenField:didFinishSearch:)]){
		[tokenField.delegate tokenField:tokenField didFinishSearch:resultsArray];
	}
	
	return resultsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	id representedObject = [resultsArray objectAtIndex:indexPath.row];
	
	if ([tokenField.delegate respondsToSelector:@selector(tokenField:resultsTableView:cellForRepresentedObject:)]){
		return [tokenField.delegate tokenField:tokenField resultsTableView:tableView cellForRepresentedObject:representedObject];
	}
	
    static NSString * CellIdentifier = @"ResultsCell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    NSString * subtitle = [self searchResultSubtitleForRepresentedObject:representedObject];
	
	if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:(subtitle ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault) reuseIdentifier:CellIdentifier] autorelease];
	
	[cell.textLabel setText:[self searchResultStringForRepresentedObject:representedObject]];
	[cell.detailTextLabel setText:subtitle];
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	id representedObject = [resultsArray objectAtIndex:indexPath.row];
    TIToken * token = [[[tokenField tokenClass] alloc] initWithTitle:[self displayStringForRepresentedObject:representedObject] representedObject:representedObject];
    [tokenField addToken:token];
	[token release];
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self setSearchResultsVisible:NO];
}

#pragma mark TextField Methods

- (void)tokenFieldDidBeginEditing:(TITokenField *)field {
	[resultsArray removeAllObjects];
	[resultsTable reloadData];
}

- (void)tokenFieldDidEndEditing:(TITokenField *)field {
	[self tokenFieldDidBeginEditing:field];
}

- (void)tokenFieldTextDidChange:(TITokenField *)field {
	[self resultsForSearchString:field.text];
}

- (void)tokenFieldFrameWillChange:(TITokenField *)field {
	
	CGFloat tokenFieldBottom = CGRectGetMaxY(tokenField.frame);
	[separator setFrame:((CGRect){{separator.frame.origin.x, tokenFieldBottom}, separator.bounds.size})];
	[resultsTable setFrame:((CGRect){{resultsTable.frame.origin.x, (tokenFieldBottom + 1)}, resultsTable.bounds.size})];
	[contentView setFrame:((CGRect){{contentView.frame.origin.x, (tokenFieldBottom + 1)}, contentView.bounds.size})];
}

- (void)tokenFieldFrameDidChange:(TITokenField *)field {
	[self updateContentSize];
}

#pragma mark Results Methods
- (NSString *)displayStringForRepresentedObject:(id)object {
	
	if ([tokenField.delegate respondsToSelector:@selector(tokenField:displayStringForRepresentedObject:)]){
		return [tokenField.delegate tokenField:tokenField displayStringForRepresentedObject:object];
	}
	
	if ([object isKindOfClass:[NSString class]]){
		return (NSString *)object;
	}
	
	return [NSString stringWithFormat:@"%@", object];
}

- (NSString *)searchResultStringForRepresentedObject:(id)object {
	
	if ([tokenField.delegate respondsToSelector:@selector(tokenField:searchResultStringForRepresentedObject:)]){
		return [tokenField.delegate tokenField:tokenField searchResultStringForRepresentedObject:object];
	}
	
	return [self displayStringForRepresentedObject:object];
}

- (NSString *)searchResultSubtitleForRepresentedObject:(id)object {
	
	if ([tokenField.delegate respondsToSelector:@selector(tokenField:searchResultSubtitleForRepresentedObject:)]){
		return [tokenField.delegate tokenField:tokenField searchResultSubtitleForRepresentedObject:object];
	}
	
	return nil;
}

- (void)setSearchResultsVisible:(BOOL)visible {
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
		
		if (visible) [self presentpopoverAtTokenFieldCaretAnimated:YES];
		else [popoverController dismissPopoverAnimated:YES];
	}
	else
	{
		[resultsTable setHidden:!visible];
		[tokenField setResultsModeEnabled:visible];
	}
}

- (void)resultsForSearchString:(NSString *)searchString {
	
	// The brute force searching method.
	// Takes the input string and compares it against everything in the source array.
	// If the source is massive, this could take some time.
	// You could always subclass and override this if needed or do it on a background thread.
	// GCD would be great for that.
	
	[resultsArray removeAllObjects];
	[resultsTable reloadData];
	
	searchString = [searchString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if (searchString.length){
		[sourceArray enumerateObjectsUsingBlock:^(id sourceObject, NSUInteger idx, BOOL *stop){
			
			NSString * query = [self searchResultStringForRepresentedObject:sourceObject];
			NSString * querySubtitle = [self searchResultSubtitleForRepresentedObject:sourceObject];
			if (!querySubtitle) querySubtitle = @"";
			
			if ([query rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound ||
				[querySubtitle rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound){
				
				__block BOOL shouldAdd = ![resultsArray containsObject:sourceObject];
				if (shouldAdd && !showAlreadyTokenized){
					
					[tokenField.tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *secondStop){
						if ([token.representedObject isEqual:sourceObject]){
							shouldAdd = NO;
							*secondStop = YES;
						}
					}];
				}
				
				if (shouldAdd) [resultsArray addObject:sourceObject];
			}
		}];
		
		[resultsArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
			return [[self searchResultStringForRepresentedObject:obj1] localizedCaseInsensitiveCompare:[self searchResultStringForRepresentedObject:obj2]];
		}];
		[resultsTable reloadData];
	}
	[self setSearchResultsVisible:(resultsArray.count > 0)];
}

- (void)presentpopoverAtTokenFieldCaretAnimated:(BOOL)animated {
	
    UITextPosition * position = [tokenField positionFromPosition:tokenField.beginningOfDocument offset:2];
	
	[popoverController presentPopoverFromRect:[tokenField caretRectForPosition:position] inView:tokenField
					 permittedArrowDirections:UIPopoverArrowDirectionUp animated:animated];
}

#pragma mark Other
- (NSString *)description {
	return [NSString stringWithFormat:@"<TITokenFieldView %p; Token count = %d>", self, self.tokenTitles.count];
}

- (void)dealloc {
	[self setDelegate:nil];
	[resultsArray release];
	[sourceArray release];
	[popoverController release];
	[super dealloc];
}

@end

//==========================================================
#pragma mark - TITokenField -
//==========================================================
NSString * const kTextEmpty = @"\u200B"; // Zero-Width Space
NSString * const kTextHidden = @"\u200D"; // Zero-Width Joiner

@interface TITokenFieldInternalDelegate ()
@property (nonatomic, assign) id <UITextFieldDelegate> delegate;
@property (nonatomic, assign) TITokenField * tokenField;
@end

@interface TITokenField ()
@property (nonatomic, readonly) CGFloat leftViewWidth;
@property (nonatomic, readonly) CGFloat rightViewWidth;
@property (nonatomic, readonly) UIScrollView * scrollView;
@property (nonatomic, readonly) UILabel *tokenSummaryLabel;
@end

@interface TITokenField (Private)
- (void)setup;
- (CGFloat)layoutTokensInternal;
@end

@implementation TITokenField
@synthesize delegate;
@synthesize tokens;
@synthesize editable;
@synthesize resultsModeEnabled;
@synthesize shouldUseResultsMode;
@synthesize removesTokensOnEndEditing;
@synthesize numberOfLines;
@synthesize selectedToken;
@synthesize tokenizingCharacters;
@synthesize hPadding;
@synthesize tokenClass;
@synthesize showingTokenSummary;
@synthesize tokenSummaryLabel;

#pragma mark Init
- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])){
		[self setup];
    }
	
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	
	if ((self = [super initWithCoder:aDecoder])){
		[self setup];
	}
	
	return self;
}

- (void)setup {
	
	[self setBorderStyle:UITextBorderStyleNone];
	[self setFont:[UIFont systemFontOfSize:14]];
	[self setBackgroundColor:[UIColor whiteColor]];
	[self setAutocorrectionType:UITextAutocorrectionTypeNo];
	[self setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	
	[self addTarget:self action:@selector(didBeginEditing) forControlEvents:UIControlEventEditingDidBegin];
	[self addTarget:self action:@selector(didEndEditing) forControlEvents:UIControlEventEditingDidEnd];
	[self addTarget:self action:@selector(didChangeText) forControlEvents:UIControlEventEditingChanged];
	
	[self.layer setShadowColor:[[UIColor blackColor] CGColor]];
	[self.layer setShadowOpacity:0.6];
	[self.layer setShadowRadius:12];
    
    tokenSummaryLabel = [[UILabel alloc] init];
    tokenSummaryLabel.backgroundColor = [UIColor clearColor];
    tokenSummaryLabel.textColor = self.textColor;
    [self addSubview:tokenSummaryLabel];
	
	[self setPromptText:@"To:"];
	[self setText:nil];
	
	internalDelegate = [[TITokenFieldInternalDelegate alloc] init];
	[internalDelegate setTokenField:self];
	[super setDelegate:internalDelegate];
	
	tokens = [[NSMutableArray alloc] init];
	editable = YES;
	removesTokensOnEndEditing = YES;
	tokenizingCharacters = [[NSCharacterSet characterSetWithCharactersInString:@","] retain];
    hPadding = 8;
    shouldUseResultsMode = YES;
}

#pragma mark Property Overrides
- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[self.layer setShadowPath:[[UIBezierPath bezierPathWithRect:self.bounds] CGPath]];
    [self.tokenSummaryLabel setFrame:[self summaryRect]];
	[self layoutTokensAnimated:NO];
}

- (void)setText:(NSString *)text {
    NSString *newText;
    
    if (text.length == 0) {
        if (self.editing == YES) {
            newText = kTextEmpty;
        } else { // Show the placeholder if not editing
            newText = nil;
        }
    } else {
        newText = text;
    }
    
    if ([self.text isEqualToString:newText]) {
        return;
    }
    
    [super setText:newText];
    [self sendActionsForControlEvents:UIControlEventEditingChanged];
}

- (void)setFont:(UIFont *)font {
	[super setFont:font];
    self.tokenSummaryLabel.font = self.font;

	if ([self.leftView isKindOfClass:[UILabel class]]){
		[self setPromptText:((UILabel *)self.leftView).text];
	}
}

- (void)showTokenSummary:(BOOL)show {
    if (showingTokenSummary == show) {
        return;
    }
    
    if (show) {
        BOOL shouldShow = !self.editing;
        if (!shouldShow) {
            return;
        }
        
		[tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop){[token removeFromSuperview];}];
		
		NSString * untokenized = kTextEmpty;
		if (tokens.count){
			
			NSMutableArray * titles = [[NSMutableArray alloc] init];
			[tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop){[titles addObject:token.title];}];
			
			untokenized = [self.tokenTitles componentsJoinedByString:@", "];
			CGSize untokSize = [untokenized sizeWithFont:[UIFont systemFontOfSize:14]];
            CGFloat additionalPadding = 4 + 4; // additional padding between left and right views
			CGFloat availableWidth = self.bounds.size.width - hPadding - additionalPadding - self.leftView.bounds.size.width - self.rightView.bounds.size.width;
			
			if (tokens.count > 1 && untokSize.width > availableWidth){
                NSString *firstTitle = titles[0];
                NSUInteger numberOfTokensAfterFirst = titles.count - 1;
				untokenized = [NSString stringWithFormat:@"%@ & %d more", firstTitle, numberOfTokensAfterFirst];
			}
			
			[titles release];
		}
		
		[self.tokenSummaryLabel setText:untokenized];
        [self.tokenSummaryLabel setHidden:NO];
        [self layoutTokensAnimated:YES];
        showingTokenSummary = YES;
    } else {
        [self.tokenSummaryLabel setText:nil];
        [self.tokenSummaryLabel setHidden:YES];
        [tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop){[self addSubview:token];}];
        [self layoutTokensAnimated:YES];
        showingTokenSummary = NO;
    }
}

- (void)setDelegate:(id<TITokenFieldDelegate>)del {
	delegate = del;
	[internalDelegate setDelegate:delegate];
}

- (void)setRightView:(UIView *)rightView_ {
    [super setRightView:rightView_];
    [self layoutTokensAnimated:YES];
}

- (NSArray *)tokens {
	return [[tokens copy] autorelease];
}

- (NSArray *)tokenTitles {
	
	NSMutableArray * titles = [[NSMutableArray alloc] init];
	[tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop){[titles addObject:token.title];}];
	return [titles autorelease];
}

- (NSArray *)tokenObjects {
	
	NSMutableArray * objects = [[NSMutableArray alloc] init];
	[tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop){
		[objects addObject:(token.representedObject ? token.representedObject : token.title)];
	}];
	return [objects autorelease];
}

- (UIScrollView *)scrollView {
	return ([self.superview isKindOfClass:[UIScrollView class]] ? (UIScrollView *)self.superview : nil);
}

- (Class)tokenClass {
    if (tokenClass != nil) {
        return tokenClass;
    } else {
        return [TIToken class];
    }
}

- (void)setTokenClass:(Class)aTokenClass {
    if ([aTokenClass isSubclassOfClass:[TIToken class]]) {
        tokenClass = aTokenClass;
    }
}

#pragma mark Event Handling
- (BOOL)becomeFirstResponder {
	return (editable ? [super becomeFirstResponder] : NO);
}

- (void)didBeginEditing {
    if (removesTokensOnEndEditing) {
        [self showTokenSummary:NO];
    }
    
    [self setText:nil];
}

- (void)didEndEditing {
	
	[selectedToken setSelected:NO];
	selectedToken = nil;
		
	if (removesTokensOnEndEditing){
		[self showTokenSummary:YES];
	}
	
	[self setResultsModeEnabled:NO];
}

- (void)didChangeText {
	if (self.text.length == 0 && self.editing == YES) [self setText:kTextEmpty];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	
	// Stop the cut, copy, select and selectAll appearing when the field is 'empty'.
	if (action == @selector(cut:) || action == @selector(copy:) || action == @selector(select:) || action == @selector(selectAll:))
		return ![self.text isEqualToString:kTextEmpty];
	
	return [super canPerformAction:action withSender:sender];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
	
	if (selectedToken && touch.view == self) [self deselectSelectedToken];
	return [super beginTrackingWithTouch:touch withEvent:event];
}

#pragma mark Token Handling
- (TIToken *)addTokenWithTitle:(NSString *)title {
	return [self addTokenWithTitle:title representedObject:nil];
}

- (TIToken *)addTokenWithTitle:(NSString *)title representedObject:(id)object {
	
	if (title.length){
		TIToken * token = [[[self tokenClass] alloc] initWithTitle:title representedObject:object font:self.font];
		[self addToken:token];
		return [token autorelease];
	}
	
	return nil;
}

- (void)addToken:(TIToken *)token {
	
	BOOL shouldAdd = YES;
	if ([delegate respondsToSelector:@selector(tokenField:willAddToken:)]){
		shouldAdd = [delegate tokenField:self willAddToken:token];
	}
	
	if (shouldAdd){
				
		[token addTarget:self action:@selector(tokenTouchDown:) forControlEvents:UIControlEventTouchDown];
		[token addTarget:self action:@selector(tokenTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:token];
		
		if (![tokens containsObject:token]) {
			[tokens addObject:token];
		
			if ([delegate respondsToSelector:@selector(tokenField:didAddToken:)]){
				[delegate tokenField:self didAddToken:token];
			}
		}
		
        if (self.shouldUseResultsMode) {
            [self setResultsModeEnabled:NO];
        } else {
            [self layoutTokensAnimated:YES];
        }
		
		[self deselectSelectedToken];
        [self setText:nil];
	}
}

- (void)removeToken:(TIToken *)token {
	
	if (token == selectedToken) [self deselectSelectedToken];
    
	BOOL shouldRemove = YES;
	if ([delegate respondsToSelector:@selector(tokenField:willRemoveToken:)]){
		shouldRemove = [delegate tokenField:self willRemoveToken:token];
	}
	
	if (shouldRemove){
		
		[[token retain] autorelease];
		
		[token removeFromSuperview];
		[tokens removeObject:token];
		
		if ([delegate respondsToSelector:@selector(tokenField:didRemoveToken:)]){
			[delegate tokenField:self didRemoveToken:token];
		}
		
        if (self.shouldUseResultsMode) {
            [self setResultsModeEnabled:NO];
        } else {
            [self layoutTokensAnimated:YES];            
        }
	}
}

- (void)removeAllTokens {
	
	[tokens enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop) {
		[self removeToken:token];
	}];
	
    [self setText:nil];
}

- (void)selectToken:(TIToken *)token {
	
	[self deselectSelectedToken];
	
	selectedToken = token;
	[selectedToken setSelected:YES];
	
	[self becomeFirstResponder];
	[self setText:kTextHidden];
    
    if ([delegate respondsToSelector:@selector(tokenField:didSelectToken:)]){
        [delegate tokenField:self didSelectToken:token];
    }
}

- (void)deselectSelectedToken {
    if (selectedToken != nil) {
        TIToken *deselectedToken = [selectedToken retain];
        
        [selectedToken setSelected:NO];
        selectedToken = nil;
        
        [self setText:nil];
        
        if ([delegate respondsToSelector:@selector(tokenField:didDeselectToken:)]){
            [delegate tokenField:self didDeselectToken:deselectedToken];
        }
        
        [deselectedToken autorelease];
    }
}

- (void)tokenizeText {
	
	__block BOOL textChanged = NO;
	
	if (![self.text isEqualToString:kTextEmpty] && ![self.text isEqualToString:kTextHidden]){
		[[self.text componentsSeparatedByCharactersInSet:tokenizingCharacters] enumerateObjectsUsingBlock:^(NSString * component, NSUInteger idx, BOOL *stop){
			[self addTokenWithTitle:[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
			textChanged = YES;
		}];
	}
	
	if (textChanged) [self sendActionsForControlEvents:UIControlEventEditingChanged];
}

- (void)tokenTouchDown:(TIToken *)token {
	
	if (selectedToken != token){
		[selectedToken setSelected:NO];
		selectedToken = nil;
	}
}

- (void)tokenTouchUpInside:(TIToken *)token {
	if (editable) [self selectToken:token];
}

- (CGFloat)layoutTokensInternal {
	
    CGFloat leftPadding = 4; // additional space between prompt and tokens/text
	CGFloat topMargin = floor(self.font.lineHeight * 4 / 7);
	CGFloat leftMargin = self.leftViewWidth + self.hPadding + leftPadding;
	CGFloat rightMargin = self.rightViewWidth + self.hPadding;
	CGFloat lineHeight = self.font.lineHeight + topMargin + 5;
	
	numberOfLines = 1;
	tokenCaret = (CGPoint){leftMargin, (topMargin - 1)};
	
	[tokens enumerateObjectsUsingBlock:^(TIToken * token, NSUInteger idx, BOOL *stop){
		
		[token setFont:self.font];
		[token setMaxWidth:(self.bounds.size.width - rightMargin - (numberOfLines > 1 ? self.hPadding : leftMargin))];
		
		if (token.superview){
			
			if (tokenCaret.x + token.bounds.size.width + rightMargin > self.bounds.size.width){
				numberOfLines++;
				tokenCaret.x = (numberOfLines > 1 ? self.hPadding : leftMargin);
				tokenCaret.y += lineHeight;
			}
			
			[token setFrame:(CGRect){tokenCaret, token.bounds.size}];
			tokenCaret.x += token.bounds.size.width + 4;
			
			if (self.bounds.size.width - tokenCaret.x - rightMargin < 50){
				numberOfLines++;
				tokenCaret.x = (numberOfLines > 1 ? self.hPadding : leftMargin);
				tokenCaret.y += lineHeight;
			}
		}
	}];
    	
	return tokenCaret.y + lineHeight;
}

#pragma mark View Handlers
- (void)layoutTokensAnimated:(BOOL)animated {
	CGFloat newHeight = [self layoutTokensInternal];
	if (self.bounds.size.height != newHeight) {
		[UIView animateWithDuration:(animated ? 0.3 : 0) delay:0 options:UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionBeginFromCurrentState animations:^{
			[self setFrame:((CGRect){self.frame.origin, {self.bounds.size.width, newHeight}})];
			[self sendActionsForControlEvents:TITokenFieldControlEventFrameWillChange];
		} completion:^(BOOL complete){
			if (complete) {
                [self sendActionsForControlEvents:TITokenFieldControlEventFrameDidChange];
            }
		}];
	}
}

- (void)setResultsModeEnabled:(BOOL)flag {
	[self setResultsModeEnabled:flag animated:YES];
}

- (void)setResultsModeEnabled:(BOOL)flag animated:(BOOL)animated {
	if (self.shouldUseResultsMode) {
        [self layoutTokensAnimated:animated];
        
        if (resultsModeEnabled != flag){
            
            //Hide / show the shadow
            [self.layer setMasksToBounds:!flag];
            
            UIScrollView * scrollView = self.scrollView;
            [scrollView setScrollsToTop:!flag];
            [scrollView setScrollEnabled:!flag];
            
            CGFloat offset = ((numberOfLines == 1 || !flag) ? 0 : tokenCaret.y - floor(self.font.lineHeight * 4 / 7) + 1);
            [scrollView setContentOffset:CGPointMake(0, self.frame.origin.y + offset) animated:animated];
        }
        
        resultsModeEnabled = flag;
    }
}

#pragma mark Left / Right view stuff
- (void)setPromptText:(NSString *)text {
	
	if (text){
		
		UILabel * label = (UILabel *)self.leftView;
		if (!label || ![label isKindOfClass:[UILabel class]]){
			label = [[UILabel alloc] initWithFrame:CGRectZero];
			[label setTextColor:[UIColor colorWithWhite:0.5 alpha:1]];
            label.backgroundColor = [UIColor clearColor];
			[self setLeftView:label];
			[label release];
			
			[self setLeftViewMode:UITextFieldViewModeAlways];
		}
		
		[label setText:text];
        [label setFont:self.font];
		[label sizeToFit];
	}
	else
	{
		[self setLeftView:nil];
	}
	
	[self layoutTokensAnimated:YES];
}

#pragma mark Layout
- (CGRect)textRectForBounds:(CGRect)bounds {
	
	if ([self.text isEqualToString:kTextHidden]) return CGRectMake(0, -20, 0, 0);
	
	CGRect frame = CGRectOffset(bounds, tokenCaret.x + 2, tokenCaret.y + 3);
	frame.size.width -= (tokenCaret.x + self.rightViewWidth + self.hPadding + 2);
	
	return frame;
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
	return [self textRectForBounds:bounds];
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
    // Only show the placeholder if there aren't any tokens
    if ([self.tokens count] == 0) {
        return [self textRectForBounds:bounds];
    } else {
        return CGRectZero;
    }
}

- (CGRect)leftViewRectForBounds:(CGRect)bounds {
    CGRect textRect = [self textRectForBounds:bounds];
    return ((CGRect){{self.hPadding, floorf(self.font.lineHeight * 4 / 7) + 2}, self.leftView.bounds.size});
}

- (CGRect)rightViewRectForBounds:(CGRect)bounds {
	return ((CGRect){{bounds.size.width - self.rightView.bounds.size.width - 6.0,
		ceilf((bounds.size.height - self.rightView.bounds.size.height) - 6.0)}, self.rightView.bounds.size});
}

- (CGFloat)leftViewWidth {
	
	if (self.leftViewMode == UITextFieldViewModeNever ||
		(self.leftViewMode == UITextFieldViewModeUnlessEditing && self.editing) ||
		(self.leftViewMode == UITextFieldViewModeWhileEditing && !self.editing)) return 0;
	
	return self.leftView.bounds.size.width;
}

- (CGFloat)rightViewWidth {
	
	if (self.rightViewMode == UITextFieldViewModeNever ||
		(self.rightViewMode == UITextFieldViewModeUnlessEditing && self.editing) ||
		(self.rightViewMode == UITextFieldViewModeWhileEditing && !self.editing)) return 0;
	
	return self.rightView.bounds.size.width;
}

- (CGRect)summaryRect {
    const CGFloat leftPadding = 4;
    CGRect rect = CGRectMake(self.leftView.frame.origin.x + self.leftView.bounds.size.width + leftPadding, 0, self.bounds.size.width - leftPadding * 2 - self.leftView.frame.origin.x - self.leftView.bounds.size.width - self.rightView.bounds.size.width, self.bounds.size.height);
    return rect;
}

#pragma mark Other
- (NSString *)description {
	return [NSString stringWithFormat:@"<TITokenField %p; prompt = \"%@\">", self, ((UILabel *)self.leftView).text];
}

- (void)dealloc {
	[self setDelegate:nil];
	[internalDelegate release];
	[tokens release];
	[tokenizingCharacters release];
    [tokenSummaryLabel release];
    [super dealloc];
}

@end

//==========================================================
#pragma mark - TITokenFieldInternalDelegate -
//==========================================================
@implementation TITokenFieldInternalDelegate
@synthesize delegate;
@synthesize tokenField;

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldShouldBeginEditing:)]){
		return [delegate textFieldShouldBeginEditing:textField];
	}
	
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldDidBeginEditing:)]){
		[delegate textFieldDidBeginEditing:textField];
	}
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldShouldEndEditing:)]){
		return [delegate textFieldShouldEndEditing:textField];
	}
	
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldDidEndEditing:)]){
		[delegate textFieldDidEndEditing:textField];
	}
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	
	if (tokenField.tokens.count && [string isEqualToString:@""] && [tokenField.text isEqualToString:kTextEmpty]){
		[tokenField selectToken:[tokenField.tokens lastObject]];
		return NO;
	}
	
	if ([textField.text isEqualToString:kTextHidden]){
		[tokenField removeToken:tokenField.selectedToken];
		return (![string isEqualToString:@""]);
	}
	
	if ([string rangeOfCharacterFromSet:tokenField.tokenizingCharacters].location != NSNotFound){
		[tokenField tokenizeText];
		return NO;
	}
	
	if ([delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]){
		return [delegate textField:textField shouldChangeCharactersInRange:range replacementString:string];
	}
	
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
		
	if ([delegate respondsToSelector:@selector(textFieldShouldReturn:)]){
		return [delegate textFieldShouldReturn:textField];
	}
	
	return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
	
	if ([delegate respondsToSelector:@selector(textFieldShouldClear:)]){
		return [delegate textFieldShouldClear:textField];
	}
	
	return YES;
}

@end


//==========================================================
#pragma mark - TIToken -
//==========================================================

CGFloat const hTextPadding = 14;
CGFloat const vTextPadding = 8;
CGFloat const kDisclosureThickness = 2.5;
UILineBreakMode const kLineBreakMode = UILineBreakModeTailTruncation;

@interface TIToken (Private)
CGPathRef CGPathCreateTokenPath(CGSize size, BOOL innerPath);
CGPathRef CGPathCreateDisclosureIndicatorPath(CGPoint arrowPointFront, CGFloat height, CGFloat thickness, CGFloat * width);
- (BOOL)getTintColorRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha;
@end

@implementation TIToken
@synthesize title;
@synthesize representedObject;
@synthesize font;
@synthesize tintColor;
@synthesize accessoryType;
@synthesize maxWidth;

#pragma mark Init
- (id)initWithTitle:(NSString *)aTitle {
	return [self initWithTitle:aTitle representedObject:nil];
}

- (id)initWithTitle:(NSString *)aTitle representedObject:(id)object {
	return [self initWithTitle:aTitle representedObject:object font:[UIFont systemFontOfSize:14]];
}

- (id)initWithTitle:(NSString *)aTitle representedObject:(id)object font:(UIFont *)aFont {
	
	if ((self = [super init])){
		
		title = [aTitle copy];
		representedObject = [object retain];
		
		font = [aFont retain];
		tintColor = [[TIToken blueTintColor] retain];
		
		accessoryType = TITokenAccessoryTypeNone;
		maxWidth = 200;
		
		[self setBackgroundColor:[UIColor clearColor]];
		[self sizeToFit];
	}
	
	return self;
}

#pragma mark Property Overrides
- (void)setHighlighted:(BOOL)flag {
	
	if (self.highlighted != flag){
		[super setHighlighted:flag];
		[self setNeedsDisplay];
	}
}

- (void)setSelected:(BOOL)flag {
	
	if (self.selected != flag){
		[super setSelected:flag];
		[self setNeedsDisplay];
	}
}

- (void)setTitle:(NSString *)newTitle {
	
	if (newTitle){
		NSString * copy = [newTitle copy];
		[title release];
		title = copy;
		
		[self sizeToFit];
	}
}

- (void)setFont:(UIFont *)newFont {
	
	if (!newFont) newFont = [UIFont systemFontOfSize:14];
	
	if (font != newFont){
		[font release];
		font = [newFont retain];
		[self sizeToFit];
	}
}

- (void)setTintColor:(UIColor *)newTintColor {
	
	if (!newTintColor) newTintColor = [TIToken blueTintColor];
	
	if (tintColor != newTintColor){
		[tintColor release];
		tintColor = [newTintColor retain];
		[self setNeedsDisplay];
	}
}

- (void)setAccessoryType:(TITokenAccessoryType)type {
	
	if (accessoryType != type){
		accessoryType = type;
		[self sizeToFit];
	}
}

- (void)setMaxWidth:(CGFloat)width {
	
	if (maxWidth != width){
		maxWidth = width;
		[self sizeToFit];
	}
}

#pragma Tint Color Convenience

+ (UIColor *)blueTintColor {
	return [UIColor colorWithRed:0.216 green:0.373 blue:0.965 alpha:1];
}

+ (UIColor *)redTintColor {
	return [UIColor colorWithRed:1 green:0.15 blue:0.15 alpha:1];
}

+ (UIColor *)greenTintColor {
	return [UIColor colorWithRed:0.333 green:0.741 blue:0.235 alpha:1];
}

#pragma mark Layout
- (void)sizeToFit {
	
	CGFloat accessoryWidth = 0;
	
	if (accessoryType == TITokenAccessoryTypeDisclosureIndicator){
		CGPathRelease(CGPathCreateDisclosureIndicatorPath(CGPointZero, font.pointSize, kDisclosureThickness, &accessoryWidth));
		accessoryWidth += floorf(hTextPadding / 2);
	}
	
	CGSize titleSize = [title sizeWithFont:font forWidth:(maxWidth - hTextPadding - accessoryWidth) lineBreakMode:kLineBreakMode];
	CGFloat height = floorf(titleSize.height + vTextPadding);
	
	[self setFrame:((CGRect){self.frame.origin, {MAX(floorf(titleSize.width + hTextPadding + accessoryWidth), height - 3), height}})];
	[self setNeedsDisplay];
}

#pragma mark Drawing
- (void)drawRect:(CGRect)rect {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// Draw the outline.
	CGContextSaveGState(context);
	CGPathRef outlinePath = CGPathCreateTokenPath(self.bounds.size, NO);
	CGContextAddPath(context, outlinePath);
	CGPathRelease(outlinePath);
	
	BOOL drawHighlighted = (self.selected || self.highlighted);
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGPoint endPoint = CGPointMake(0, self.bounds.size.height);
	
	CGFloat red = 1;
	CGFloat green = 1;
	CGFloat blue = 1;
	CGFloat alpha = 1;
	[self getTintColorRed:&red green:&green blue:&blue alpha:&alpha];
	
	if (drawHighlighted){
		CGContextSetFillColor(context, (CGFloat[4]){red, green, blue, 1});
		CGContextFillPath(context);
	}
	else
	{
		CGContextClip(context);
		CGFloat locations[2] = {0, 0.95};
		CGFloat components[8] = {red + 0.2, green + 0.2, blue + 0.2, alpha, red, green, blue, 0.8};
		CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 2);
		CGContextDrawLinearGradient(context, gradient, CGPointZero, endPoint, 0);
		CGGradientRelease(gradient);
	}
	
	CGContextRestoreGState(context);
	
	CGPathRef innerPath = CGPathCreateTokenPath(self.bounds.size, YES);
    
    // Draw a white background so we can use alpha to lighten the inner gradient
    CGContextSaveGState(context);
	CGContextAddPath(context, innerPath);
    CGContextSetFillColor(context, (CGFloat[4]){1, 1, 1, 1});
    CGContextFillPath(context);
    CGContextRestoreGState(context);
	
	// Draw the inner gradient.
	CGContextSaveGState(context);
	CGContextAddPath(context, innerPath);
	CGPathRelease(innerPath);
	CGContextClip(context);
	
	CGFloat locations[2] = {0, (drawHighlighted ? 0.9 : 0.6)};
    CGFloat highlightedComp[8] = {red, green, blue, 0.7, red, green, blue, 1};
    CGFloat nonHighlightedComp[8] = {red, green, blue, 0.15, red, green, blue, 0.3};
	
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, (drawHighlighted ? highlightedComp : nonHighlightedComp), locations, 2);
	CGContextDrawLinearGradient(context, gradient, CGPointZero, endPoint, 0);
	CGGradientRelease(gradient);
	CGContextRestoreGState(context);
	
	CGFloat accessoryWidth = 0;
	
	if (accessoryType == TITokenAccessoryTypeDisclosureIndicator){
		CGPoint arrowPoint = CGPointMake(self.bounds.size.width - floorf(hTextPadding / 2), (self.bounds.size.height / 2) - 1);
		CGPathRef disclosurePath = CGPathCreateDisclosureIndicatorPath(arrowPoint, font.pointSize, kDisclosureThickness, &accessoryWidth);
		accessoryWidth += floorf(hTextPadding / 2);
		
		CGContextAddPath(context, disclosurePath);
		CGContextSetFillColor(context, (CGFloat[4]){1, 1, 1, 1});
		
		if (drawHighlighted){
			CGContextFillPath(context);
		}
		else
		{
			CGContextSaveGState(context);
			CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1, [[[UIColor whiteColor] colorWithAlphaComponent:0.6] CGColor]);
			CGContextFillPath(context);
			CGContextRestoreGState(context);
			
			CGContextSaveGState(context);
			CGContextAddPath(context, disclosurePath);
			CGContextClip(context);
			
			CGGradientRef disclosureGradient = CGGradientCreateWithColorComponents(colorspace, highlightedComp, NULL, 2);
			CGContextDrawLinearGradient(context, disclosureGradient, CGPointZero, endPoint, 0);
			CGGradientRelease(disclosureGradient);
			
			arrowPoint.y += 0.5;
			CGPathRef innerShadowPath = CGPathCreateDisclosureIndicatorPath(arrowPoint, font.pointSize, kDisclosureThickness, NULL);
			CGContextAddPath(context, innerShadowPath);
			CGPathRelease(innerShadowPath);
			CGContextSetStrokeColor(context, (CGFloat[4]){0, 0, 0, 0.3});
			CGContextStrokePath(context);
			CGContextRestoreGState(context);
		}
		
		CGPathRelease(disclosurePath);
	}
	
	CGColorSpaceRelease(colorspace);
	
	CGSize titleSize = [title sizeWithFont:font forWidth:(maxWidth - hTextPadding - accessoryWidth) lineBreakMode:kLineBreakMode];
	CGFloat vPadding = floor((self.bounds.size.height - titleSize.height) / 2);
	CGFloat titleWidth = ceilf(self.bounds.size.width - hTextPadding - accessoryWidth);
	CGRect textBounds = CGRectMake(floorf(hTextPadding / 2), vPadding - 1, titleWidth, floorf(self.bounds.size.height - (vPadding * 2)));
	
	CGContextSetFillColor(context, (drawHighlighted ? (CGFloat[4]){1, 1, 1, 1} : (CGFloat[4]){0, 0, 0, 1}));
	[title drawInRect:textBounds withFont:font lineBreakMode:kLineBreakMode];
}

CGPathRef CGPathCreateTokenPath(CGSize size, BOOL innerPath) {
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGFloat arcValue = (size.height / 2) - 1;
	CGFloat radius = arcValue - (innerPath ? (1 / [[UIScreen mainScreen] scale]) : 0);
	CGPathAddArc(path, NULL, arcValue, arcValue, radius, (M_PI / 2), (M_PI * 3 / 2), NO);
	CGPathAddArc(path, NULL, size.width - arcValue, arcValue, radius, (M_PI  * 3 / 2), (M_PI / 2), NO);
	CGPathCloseSubpath(path);
	
	return path;
}

CGPathRef CGPathCreateDisclosureIndicatorPath(CGPoint arrowPointFront, CGFloat height, CGFloat thickness, CGFloat * width) {
	
	thickness /= cosf(M_PI / 4);
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, NULL, arrowPointFront.x, arrowPointFront.y);
	
	CGPoint bottomPointFront = CGPointMake(arrowPointFront.x - (height / (2 * tanf(M_PI / 4))), arrowPointFront.y - height / 2);
	CGPathAddLineToPoint(path, NULL, bottomPointFront.x, bottomPointFront.y);
	
	CGPoint bottomPointBack = CGPointMake(bottomPointFront.x - thickness * cosf(M_PI / 4),  bottomPointFront.y + thickness * sinf(M_PI / 4));
	CGPathAddLineToPoint(path, NULL, bottomPointBack.x, bottomPointBack.y);
	
	CGPoint arrowPointBack = CGPointMake(arrowPointFront.x - thickness / cosf(M_PI / 4), arrowPointFront.y);
	CGPathAddLineToPoint(path, NULL, arrowPointBack.x, arrowPointBack.y);
	
	CGPoint topPointFront = CGPointMake(bottomPointFront.x, arrowPointFront.y + height / 2);
	CGPoint topPointBack = CGPointMake(bottomPointBack.x, topPointFront.y - thickness * sinf(M_PI / 4));
	
	CGPathAddLineToPoint(path, NULL, topPointBack.x, topPointBack.y);
	CGPathAddLineToPoint(path, NULL, topPointFront.x, topPointFront.y);
	CGPathAddLineToPoint(path, NULL, arrowPointFront.x, arrowPointFront.y);
	
	if (width) *width = (arrowPointFront.x - topPointBack.x);
	return path;
}

- (BOOL)getTintColorRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha {
	
	CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(CGColorGetColorSpace(tintColor.CGColor));
	const CGFloat * components = CGColorGetComponents(tintColor.CGColor);
	
	if (colorSpaceModel == kCGColorSpaceModelMonochrome || colorSpaceModel == kCGColorSpaceModelRGB){
		
		if (red) *red = components[0];
		if (green) *green = (colorSpaceModel == kCGColorSpaceModelMonochrome ? components[0] : components[1]);
		if (blue) *blue = (colorSpaceModel == kCGColorSpaceModelMonochrome ? components[0] : components[2]);
		if (alpha) *alpha = (colorSpaceModel == kCGColorSpaceModelMonochrome ? components[1] : components[3]);
		
		return YES;
	}
	
	return NO;
}

#pragma mark Other
- (NSString *)description {
	return [NSString stringWithFormat:@"<TIToken %p; title = \"%@\"; representedObject = \"%@\">", self, title, representedObject];
}

- (void)dealloc {
	[title release];
	[representedObject release];
	[font release];
	[tintColor release];
    [super dealloc];
}

@end
