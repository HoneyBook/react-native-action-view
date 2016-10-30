/*
 * MGSwipeTableCell is licensed under MIT license. See LICENSE.md file for more information.
 * Copyright (c) 2014 Imanol Fernandez @MortimerGoro
 */

#import "MGSwipeView.h"

#pragma mark Input Overlay Helper Class
/** Used to capture table input while swipe buttons are visible*/
@interface MGSwipeViewInputOverlay : UIView
@property (nonatomic, weak) MGSwipeView * currentView;
@end

@implementation MGSwipeViewInputOverlay

-(id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

-(UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (event == nil) {
        return nil;
    }
    if (!_currentView) {
        [self removeFromSuperview];
        return nil;
    }
    CGPoint p = [self convertPoint:point toView:_currentView];
    if (_currentView && (_currentView.hidden || CGRectContainsPoint(_currentView.bounds, p))) {
        return nil;
    }
    BOOL hide = YES;
    if (_currentView && _currentView.delegate && [_currentView.delegate respondsToSelector:@selector(swipeView:shouldHideSwipeOnTap:)]) {
        hide = [_currentView.delegate swipeView:_currentView shouldHideSwipeOnTap:p];
    }
    if (hide) {
        [_currentView hideSwipeAnimated:YES];
    }
    return _currentView.touchOnDismissSwipe ? nil : self;
}

@end

#pragma mark Button Container View and transitions

@interface MGSwipeButtonsView : UIView
@property (nonatomic, weak) MGSwipeView * view;
@property (nonatomic, strong) UIColor * backgroundColorCopy;
@end

@implementation MGSwipeButtonsView
{
    NSArray<UIView*> * _buttons;
    UIView * _container;
    BOOL _fromLeft;
    UIView * _expandedButton;
    UIView * _expandedButtonAnimated;
    UIView * _expansionBackground;
    UIView * _expansionBackgroundAnimated;
    CGRect _expandedButtonBoundsCopy;
    MGSwipeExpansionLayout _expansionLayout;
    CGFloat _expansionOffset;
    BOOL _autoHideExpansion;
}

#pragma mark Layout

-(instancetype) initWithButtons:(NSArray*) buttonsArray direction:(MGSwipeDirection) direction differentWidth:(BOOL) differentWidth
{
    CGFloat containerWidth = 0;
    CGSize maxSize = CGSizeZero;

    for (UIView * button in buttonsArray) {
        containerWidth += button.bounds.size.width;
        maxSize.width = MAX(maxSize.width, button.bounds.size.width);
        maxSize.height = MAX(maxSize.height, button.bounds.size.height);
    }
    if (!differentWidth) {
        containerWidth = maxSize.width * buttonsArray.count;
    }
    
    if (self = [super initWithFrame:CGRectMake(0, 0, containerWidth, maxSize.height)]) {
        _fromLeft = direction == MGSwipeDirectionLeftToRight;
        _container = [[UIView alloc] initWithFrame:self.bounds];
        _container.clipsToBounds = YES;
        _container.backgroundColor = [UIColor clearColor];
        [self addSubview:_container];
        _buttons = _fromLeft ? buttonsArray: [[buttonsArray reverseObjectEnumerator] allObjects];
        for (UIView * button in _buttons) {
            if ([button isKindOfClass:[UIButton class]]) {
                UIButton * btn = (UIButton*)button;
                [btn removeTarget:nil action:@selector(mgButtonClicked:) forControlEvents:UIControlEventTouchUpInside]; //Remove all targets to avoid problems with reused buttons among many views
                [btn addTarget:self action:@selector(mgButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
            }
            if (!differentWidth) {
                button.frame = CGRectMake(0, 0, maxSize.width, maxSize.height);
            }
            button.autoresizingMask = UIViewAutoresizingFlexibleHeight;
            [_container insertSubview:button atIndex: _fromLeft ? 0: _container.subviews.count];
        }
        [self resetButtons];
    }
    return self;
}

-(void) dealloc
{
    for (UIView * button in _buttons) {
        if ([button isKindOfClass:[UIButton class]]) {
            [(UIButton *)button removeTarget:self action:@selector(mgButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        }
    }
}

-(void) resetButtons
{
    CGFloat offsetX = 0;
    for (UIView * button in _buttons) {
        button.frame = CGRectMake(offsetX, 0, button.bounds.size.width, self.bounds.size.height);
        button.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        offsetX += button.bounds.size.width;
    }
}

-(void) layoutExpansion: (CGFloat) offset
{
    _expansionOffset = offset;
    _container.frame = CGRectMake(_fromLeft ? 0: self.bounds.size.width - offset, 0, offset, self.bounds.size.height);
    if (_expansionBackgroundAnimated && _expandedButtonAnimated) {
        _expansionBackgroundAnimated.frame = [self expansionBackgroundRect:_expandedButtonAnimated];
    }
}

-(void) layoutSubviews
{
    [super layoutSubviews];
    if (_expandedButton) {
        [self layoutExpansion:_expansionOffset];
    }
    else {
        _container.frame = self.bounds;
    }
}

-(CGRect) expansionBackgroundRect: (UIView *) button
{
    CGFloat extra = 100.0f; //extra size to avoid expansion background size issue on iOS 7.0
    if (_fromLeft) {
        return CGRectMake(-extra, 0, button.frame.origin.x + extra, _container.bounds.size.height);
    }
    else {
        return CGRectMake(button.frame.origin.x +  button.bounds.size.width, 0,
                   _container.bounds.size.width - (button.frame.origin.x + button.bounds.size.width ) + extra
                          ,_container.bounds.size.height);
    }
    
}

-(void) expandToOffset:(CGFloat) offset settings:(MGSwipeExpansionSettings*) settings
{
    if (settings.buttonIndex < 0 || settings.buttonIndex >= _buttons.count) {
        return;
    }
    if (!_expandedButton) {
        _expandedButton = [_buttons objectAtIndex: _fromLeft ? settings.buttonIndex : _buttons.count - settings.buttonIndex - 1];
        CGRect previusRect = _container.frame;
        [self layoutExpansion:offset];
        [self resetButtons];
        if (!_fromLeft) { //Fix expansion animation for right buttons
            for (UIView * button in _buttons) {
                CGRect frame = button.frame;
                frame.origin.x += _container.bounds.size.width - previusRect.size.width;
                button.frame = frame;
            }
        }
        _expansionBackground = [[UIView alloc] initWithFrame:[self expansionBackgroundRect:_expandedButton]];
        _expansionBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        if (settings.expansionColor) {
            _backgroundColorCopy = _expandedButton.backgroundColor;
            _expandedButton.backgroundColor = settings.expansionColor;
        }
        _expansionBackground.backgroundColor = _expandedButton.backgroundColor;
        if (UIColor.clearColor == _expandedButton.backgroundColor) {
          // Provides access to more complex content for display on the background
          _expansionBackground.layer.contents = _expandedButton.layer.contents;
        }
        [_container addSubview:_expansionBackground];
        _expansionLayout = settings.expansionLayout;
        
        CGFloat duration = _fromLeft ? _view.leftExpansion.animationDuration : _view.rightExpansion.animationDuration;
        [UIView animateWithDuration: duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            _expandedButton.hidden = NO;

            if (_expansionLayout == MGSwipeExpansionLayoutCenter) {
                _expandedButtonBoundsCopy = _expandedButton.bounds;
                _expandedButton.layer.mask = nil;
                _expandedButton.layer.transform = CATransform3DIdentity;
                _expandedButton.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
                [_expandedButton.superview bringSubviewToFront:_expandedButton];
                _expandedButton.frame = _container.bounds;
            }
            else if (_fromLeft) {
                _expandedButton.frame = CGRectMake(_container.bounds.size.width - _expandedButton.bounds.size.width, 0, _expandedButton.bounds.size.width, _expandedButton.bounds.size.height);
                _expandedButton.autoresizingMask|= UIViewAutoresizingFlexibleLeftMargin;
            }
            else {
                _expandedButton.frame = CGRectMake(0, 0, _expandedButton.bounds.size.width, _expandedButton.bounds.size.height);
                _expandedButton.autoresizingMask|= UIViewAutoresizingFlexibleRightMargin;
            }
            _expansionBackground.frame = [self expansionBackgroundRect:_expandedButton];

        } completion:^(BOOL finished) {
        }];
        return;
    }
    [self layoutExpansion:offset];
}

-(void) endExpansionAnimated:(BOOL) animated
{
    if (_expandedButton) {
        _expandedButtonAnimated = _expandedButton;
        if (_expansionBackgroundAnimated && _expansionBackgroundAnimated != _expansionBackground) {
            [_expansionBackgroundAnimated removeFromSuperview];
        }
        _expansionBackgroundAnimated = _expansionBackground;
        _expansionBackground = nil;
        _expandedButton = nil;
        if (_backgroundColorCopy) {
            _expansionBackgroundAnimated.backgroundColor = _backgroundColorCopy;
            _expandedButtonAnimated.backgroundColor = _backgroundColorCopy;
            _backgroundColorCopy = nil;
        }
        CGFloat duration = _fromLeft ? _view.leftExpansion.animationDuration : _view.rightExpansion.animationDuration;
        [UIView animateWithDuration: animated ? duration : 0.0 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            _container.frame = self.bounds;
            if (_expansionLayout == MGSwipeExpansionLayoutCenter) {
                _expandedButtonAnimated.frame = _expandedButtonBoundsCopy;
            }
            [self resetButtons];
            _expansionBackgroundAnimated.frame = [self expansionBackgroundRect:_expandedButtonAnimated];
        } completion:^(BOOL finished) {
            [_expansionBackgroundAnimated removeFromSuperview];
        }];
    }
    else if (_expansionBackground) {
        [_expansionBackground removeFromSuperview];
        _expansionBackground = nil;
    }
}

-(UIView*) getExpandedButton
{
    return _expandedButton;
}

#pragma mark Trigger Actions

-(BOOL) handleClick: (id) sender fromExpansion:(BOOL) fromExpansion
{
    bool autoHide = false;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([sender respondsToSelector:@selector(callMGSwipeConvenienceCallback:)]) {
        //call convenience block callback if exits (usage of MGSwipeButton class is not compulsory)
        autoHide = [sender performSelector:@selector(callMGSwipeConvenienceCallback:) withObject:_view];
    }
#pragma clang diagnostic pop
    
    if (_view.delegate && [_view.delegate respondsToSelector:@selector(swipeView:tappedButtonAtIndex:direction:fromExpansion:)]) {
        NSInteger index = [_buttons indexOfObject:sender];
        if (!_fromLeft) {
            index = _buttons.count - index - 1; //right buttons are reversed
        }
        autoHide|= [_view.delegate swipeView:_view tappedButtonAtIndex:index direction:_fromLeft ? MGSwipeDirectionLeftToRight : MGSwipeDirectionRightToLeft fromExpansion:fromExpansion];
    }
    
    if (fromExpansion && autoHide) {
        _expandedButton = nil;
        _view.swipeOffset = 0;
    }
    else if (autoHide) {
        [_view hideSwipeAnimated:YES];
    }
    
    return autoHide;

}
//button listener
-(void) mgButtonClicked: (id) sender
{
    [self handleClick:sender fromExpansion:NO];
}


#pragma mark Transitions

-(void) transitionStatic:(CGFloat) t
{
    const CGFloat dx = self.bounds.size.width * (1.0 - t);
    CGFloat offsetX = 0;
    
    for (UIView *button in _buttons) {
		CGRect bounds = button.bounds;
        button.bounds = bounds;
		button.center = CGPointMake(offsetX + (_fromLeft ? dx : -dx) + bounds.size.width / 2, button.center.y);
        offsetX += bounds.size.width;
    }
}

-(void) transitionDrag:(CGFloat) t
{
    //No Op, nothing to do ;)
}

-(void) transitionClip:(CGFloat) t
{
    CGFloat selfWidth = self.bounds.size.width;
    CGFloat offsetX = 0;
    
    for (UIView *button in _buttons) {
        CGRect frame = button.frame;
        CGFloat dx = roundf(frame.size.width * 0.5 * (1.0 - t)) ;
        frame.origin.x = _fromLeft ? (selfWidth - frame.size.width - offsetX) * (1.0 - t) + offsetX + dx : offsetX * t - dx;
        button.frame = frame;

        if (_buttons.count > 1) {
            CAShapeLayer *maskLayer = [CAShapeLayer new];
            CGRect maskRect = CGRectMake(dx - 0.5, 0, frame.size.width - 2 * dx + 1.5, frame.size.height);
            CGPathRef path = CGPathCreateWithRect(maskRect, NULL);
            maskLayer.path = path;
            CGPathRelease(path);
            button.layer.mask = maskLayer;
        }

        offsetX += frame.size.width;
    }
}

-(void) transtitionFloatBorder:(CGFloat) t
{
    CGFloat selfWidth = self.bounds.size.width;
    CGFloat offsetX = 0;
    
    for (UIView *button in _buttons) {
        CGRect frame = button.frame;
        frame.origin.x = _fromLeft ? (selfWidth - frame.size.width - offsetX) * (1.0 - t) + offsetX : offsetX * t;
        button.frame = frame;
        offsetX += frame.size.width;
    }
}

-(void) transition3D:(CGFloat) t
{
    const CGFloat invert = _fromLeft ? 1.0 : -1.0;
    const CGFloat angle = M_PI_2 * (1.0 - t) * invert;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0/400.0f; //perspective 1/z
    const CGFloat dx = -_container.bounds.size.width * 0.5 * invert;
    const CGFloat offset = dx * 2 * (1.0 - t);
    transform = CATransform3DTranslate(transform, dx - offset, 0, 0);
    transform = CATransform3DRotate(transform, angle, 0.0, 1.0, 0.0);
    transform = CATransform3DTranslate(transform, -dx, 0, 0);
    _container.layer.transform = transform;
}

static CGFloat _clamp(CGFloat x, CGFloat lower, CGFloat upper)
{
	if(x < lower)
	{
		return lower;
	}
	if(x > upper)
	{
		return upper;
	}
	
	return x;
}

static CGFloat _pointOnLine(CGFloat x, CGFloat x1, CGFloat x2, CGFloat y1, CGFloat y2)
{
	return (y2 - y1) / (x2 - x1) * (x - x1) + y1;
}

- (void)transitionGrow:(CGFloat)t
{
	[self transitionStatic:t];

	[_buttons enumerateObjectsUsingBlock:^(UIView * _Nonnull button, NSUInteger idx, BOOL * _Nonnull stop) {
		CGFloat startPercentage = ((CGFloat)idx / (_buttons.count));
		CGFloat endPercentage = ((CGFloat)idx / (_buttons.count));
		
		if(!_fromLeft)
		{
			endPercentage +=  (1.0 / (_buttons.count)) / 2;
			startPercentage +=  (1.0 / (_buttons.count));
			
			startPercentage = 1.0 - startPercentage;
			endPercentage = 1.0 - endPercentage;
		}
		else
		{
			endPercentage +=  (1.0 / (_buttons.count));
			startPercentage += (1.0 / (_buttons.count)) / 2;
		}
		
		CGFloat y = _pointOnLine(_clamp(t, startPercentage, endPercentage), startPercentage, endPercentage, 0, 1);
		
		if(idx == 2)
		{
			NSLog(@"%lf", y);
		}
		
		CGFloat scale = 0.6 + 0.4 * y;
		button.transform = CGAffineTransformMakeScale(scale, scale);
	}];
}

-(void) transition:(MGSwipeTransition) mode percent:(CGFloat) t
{
    switch (mode) {
        case MGSwipeTransitionStatic: [self transitionStatic:t]; break;
        case MGSwipeTransitionDrag: [self transitionDrag:t]; break;
        case MGSwipeTransitionClipCenter: [self transitionClip:t]; break;
        case MGSwipeTransitionBorder: [self transtitionFloatBorder:t]; break;
        case MGSwipeTransitionRotate3D: [self transition3D:t]; break;
		case MGSwipeTransitionGrow: [self transitionGrow:t]; break;
    }
    if (_expandedButtonAnimated && _expansionBackgroundAnimated) {
        _expansionBackgroundAnimated.frame = [self expansionBackgroundRect:_expandedButtonAnimated];
    }
}

@end

#pragma mark Settings Classes
@implementation MGSwipeSettings
-(instancetype) init
{
    if (self = [super init]) {
        self.transition = MGSwipeTransitionBorder;
        self.threshold = 0.5;
        self.offset = 0;
        self.keepButtonsSwiped = YES;
        self.enableSwipeBounces = YES;
        self.showAnimation = [[MGSwipeAnimation alloc] init];
        self.hideAnimation = [[MGSwipeAnimation alloc] init];
        self.stretchAnimation = [[MGSwipeAnimation alloc] init];
    }
    return self;
}

-(void) setAnimationDuration:(CGFloat)duration
{
    _showAnimation.duration = duration;
    _hideAnimation.duration = duration;
    _stretchAnimation.duration = duration;
}

-(CGFloat) animationDuration {
    return _showAnimation.duration;
}

@end

@implementation MGSwipeExpansionSettings
-(instancetype) init
{
    if (self = [super init]) {
        self.buttonIndex = -1;
        self.threshold = 1.3;
        self.animationDuration = 0.2;
        self.triggerAnimation = [[MGSwipeAnimation alloc] init];
    }
    return self;
}
@end

@interface MGSwipeAnimationData : NSObject
@property (nonatomic, assign) CGFloat from;
@property (nonatomic, assign) CGFloat to;
@property (nonatomic, assign) CFTimeInterval duration;
@property (nonatomic, assign) CFTimeInterval start;
@property (nonatomic, strong) MGSwipeAnimation * animation;

@end

@implementation MGSwipeAnimationData
@end


#pragma mark Easing Functions and MGSwipeAnimation

static inline CGFloat mgEaseLinear(CGFloat t, CGFloat b, CGFloat c) {
    return c*t + b;
}

static inline CGFloat mgEaseInQuad(CGFloat t, CGFloat b, CGFloat c) {
    return c*t*t + b;
}
static inline CGFloat mgEaseOutQuad(CGFloat t, CGFloat b, CGFloat c) {
    return -c*t*(t-2) + b;
}
static inline CGFloat mgEaseInOutQuad(CGFloat t, CGFloat b, CGFloat c) {
    if ((t*=2) < 1) return c/2*t*t + b;
    --t;
    return -c/2 * (t*(t-2) - 1) + b;
}
static inline CGFloat mgEaseInCubic(CGFloat t, CGFloat b, CGFloat c) {
    return c*t*t*t + b;
}
static inline CGFloat mgEaseOutCubic(CGFloat t, CGFloat b, CGFloat c) {
    --t;
    return c*(t*t*t + 1) + b;
}
static inline CGFloat mgEaseInOutCubic(CGFloat t, CGFloat b, CGFloat c) {
    if ((t*=2) < 1) return c/2*t*t*t + b;
    t-=2;
    return c/2*(t*t*t + 2) + b;
}
static inline CGFloat mgEaseOutBounce(CGFloat t, CGFloat b, CGFloat c) {
    if (t < (1/2.75)) {
        return c*(7.5625*t*t) + b;
    } else if (t < (2/2.75)) {
        t-=(1.5/2.75);
        return c*(7.5625*t*t + .75) + b;
    } else if (t < (2.5/2.75)) {
        t-=(2.25/2.75);
        return c*(7.5625*t*t + .9375) + b;
    } else {
        t-=(2.625/2.75);
        return c*(7.5625*t*t + .984375) + b;
    }
};
static inline CGFloat mgEaseInBounce(CGFloat t, CGFloat b, CGFloat c) {
    return c - mgEaseOutBounce (1.0 -t, 0, c) + b;
};

static inline CGFloat mgEaseInOutBounce(CGFloat t, CGFloat b, CGFloat c) {
    if (t < 0.5) return mgEaseInBounce (t*2, 0, c) * .5 + b;
    return mgEaseOutBounce (1.0 - t*2, 0, c) * .5 + c*.5 + b;
};

@implementation MGSwipeAnimation

-(instancetype) init {
    if (self = [super init]) {
        _duration = 0.3;
        _easingFunction = MGSwipeEasingFunctionCubicOut;
    }
    return self;
}

-(CGFloat) value:(CGFloat)elapsed duration:(CGFloat)duration from:(CGFloat)from to:(CGFloat)to
{
    CGFloat t = MIN(elapsed/duration, 1.0f);
    if (t == 1.0) {
        return to; //precise last value
    }
    CGFloat (*easingFunction)(CGFloat t, CGFloat b, CGFloat c) = 0;
    switch (_easingFunction) {
        case MGSwipeEasingFunctionLinear: easingFunction = mgEaseLinear;break;
        case MGSwipeEasingFunctionQuadIn: easingFunction = mgEaseInQuad;break;
        case MGSwipeEasingFunctionQuadOut: easingFunction = mgEaseOutQuad;break;
        case MGSwipeEasingFunctionQuadInOut: easingFunction = mgEaseInOutQuad;break;
        case MGSwipeEasingFunctionCubicIn: easingFunction = mgEaseInCubic;break;
        default:
        case MGSwipeEasingFunctionCubicOut: easingFunction = mgEaseOutCubic;break;
        case MGSwipeEasingFunctionCubicInOut: easingFunction = mgEaseInOutCubic;break;
        case MGSwipeEasingFunctionBounceIn: easingFunction = mgEaseInBounce;break;
        case MGSwipeEasingFunctionBounceOut: easingFunction = mgEaseOutBounce;break;
        case MGSwipeEasingFunctionBounceInOut: easingFunction = mgEaseInOutBounce;break;
    }
    return (*easingFunction)(t, from, to - from);
}

@end

#pragma mark MGSwipeView Implementation

@interface MGSwipeView () <UIGestureRecognizerDelegate>

@end


@implementation MGSwipeView
{
    UITapGestureRecognizer * _tapRecognizer;
    UIPanGestureRecognizer * _panRecognizer;
    CGPoint _panStartPoint;
    CGFloat _panStartOffset;
    CGFloat _targetOffset;
    
    UIView * _swipeOverlay;
    UIImageView * _swipeView;
    UIView * _swipeContentView;
    MGSwipeButtonsView * _leftView;
    MGSwipeButtonsView * _rightView;
    bool _allowSwipeRightToLeft;
    bool _allowSwipeLeftToRight;
    __weak MGSwipeButtonsView * _activeExpansion;

    MGSwipeViewInputOverlay * _tableInputOverlay;
    bool _overlayEnabled;
	NSMutableSet * _previusHiddenViews;
    BOOL _triggerStateChanges;
    
    MGSwipeAnimationData * _animationData;
    void (^_animationCompletion)(BOOL finished);
    CADisplayLink * _displayLink;
    MGSwipeState _firstSwipeState;
	
	NSMutableSet<UIGestureRecognizer*>* _rnGestureRecognizers;
}

#pragma mark View creation & layout

- (id)initWithFrame:(CGRect)frame
{
	if(self = [super initWithFrame:frame]) {
		[self initViews:YES];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    if(self = [super initWithCoder:aDecoder]) {
        [self initViews:YES];
    }
    return self;
}

-(void) awakeFromNib
{
    [super awakeFromNib];
    if (!_panRecognizer) {
        [self initViews:YES];
    }
}

-(void) dealloc
{
    [self hideSwipeOverlayIfNeeded];
}

-(void) initViews: (BOOL) cleanButtons
{
    if (cleanButtons) {
        _leftButtons = [NSArray array];
        _rightButtons = [NSArray array];
        _leftSwipeSettings = [[MGSwipeSettings alloc] init];
        _rightSwipeSettings = [[MGSwipeSettings alloc] init];
        _leftExpansion = [[MGSwipeExpansionSettings alloc] init];
        _rightExpansion = [[MGSwipeExpansionSettings alloc] init];
    }
    _animationData = [[MGSwipeAnimationData alloc] init];
    _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panHandler:)];
    [self addGestureRecognizer:_panRecognizer];
    _panRecognizer.delegate = self;
    _activeExpansion = nil;
    _previusHiddenViews = [NSMutableSet set];
    _swipeState = MGSwipeStateNone;
    _triggerStateChanges = YES;
    _allowsSwipeWhenTappingButtons = YES;
    _allowsOppositeSwipe = NO;
    _firstSwipeState = MGSwipeStateNone;
    
}

-(void) cleanViews
{
    [self hideSwipeAnimated:NO];
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    if (_swipeOverlay) {
        [_swipeOverlay removeFromSuperview];
        _swipeOverlay = nil;
    }
    _leftView = _rightView = nil;
    if (_panRecognizer) {
        _panRecognizer.delegate = nil;
        [self removeGestureRecognizer:_panRecognizer];
        _panRecognizer = nil;
    }
}

-(BOOL) isRTLLocale
{
    if ([[UIView class] respondsToSelector:@selector(userInterfaceLayoutDirectionForSemanticContentAttribute:)]) {
        return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.semanticContentAttribute] == UIUserInterfaceLayoutDirectionRightToLeft;
    }
#ifndef TARGET_IS_EXTENSION
    else {
        return [UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    }
#else
    return NO;
#endif
}

-(void) fixRegionAndAccesoryViews
{
    //Fix right to left layout direction for arabic and hebrew languagues
    if (self.bounds.size.width != self.bounds.size.width && [self isRTLLocale]) {
        _swipeOverlay.frame = CGRectMake(-self.bounds.size.width + self.bounds.size.width, 0, _swipeOverlay.bounds.size.width, _swipeOverlay.bounds.size.height);
    }
}

-(UIView *) swipeContentView
{
    if (!_swipeContentView) {
        _swipeContentView = [[UIView alloc] initWithFrame:self.bounds];
        _swipeContentView.backgroundColor = [UIColor clearColor];
        _swipeContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _swipeContentView.layer.zPosition = 9;
        [self addSubview:_swipeContentView];
    }
    return _swipeContentView;
}

-(void) layoutSubviews
{
    [super layoutSubviews];
    if (_swipeContentView) {
        _swipeContentView.frame = self.bounds;
    }
    if (_swipeOverlay) {
        CGSize prevSize = _swipeView.bounds.size;
        _swipeOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        [self fixRegionAndAccesoryViews];
        if (_swipeView.image &&  !CGSizeEqualToSize(prevSize, _swipeOverlay.bounds.size)) {
            //refresh contentView in situations like layout change, orientation chage, table resize, etc.
            [self refreshContentView];
        }
    }
}

-(void) fetchButtonsIfNeeded
{
    if (_leftButtons.count == 0 && _delegate && [_delegate respondsToSelector:@selector(swipeView:swipeButtonsForDirection:swipeSettings:expansionSettings:)]) {
        _leftButtons = [_delegate swipeView:self swipeButtonsForDirection:MGSwipeDirectionLeftToRight swipeSettings:_leftSwipeSettings expansionSettings:_leftExpansion];
    }
    if (_rightButtons.count == 0 && _delegate && [_delegate respondsToSelector:@selector(swipeView:swipeButtonsForDirection:swipeSettings:expansionSettings:)]) {
        _rightButtons = [_delegate swipeView:self swipeButtonsForDirection:MGSwipeDirectionRightToLeft swipeSettings:_rightSwipeSettings expansionSettings:_rightExpansion];
    }
}

-(void) createSwipeViewIfNeeded
{
    if (!_swipeOverlay) {
        _swipeOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        [self fixRegionAndAccesoryViews];
        _swipeOverlay.hidden = YES;
        _swipeOverlay.backgroundColor = [self backgroundColorForSwipe];
        _swipeOverlay.layer.zPosition = 10; //force render on top of the contentView;
        _swipeView = [[UIImageView alloc] initWithFrame:_swipeOverlay.bounds];
		_swipeView.backgroundColor = [UIColor whiteColor];
        _swipeView.autoresizingMask =  UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _swipeView.contentMode = UIViewContentModeCenter;
        _swipeView.clipsToBounds = YES;
        [_swipeOverlay addSubview:_swipeView];
        [self addSubview:_swipeOverlay];
    }
    
    [self fetchButtonsIfNeeded];
    if (!_leftView && _leftButtons.count > 0) {
        _leftView = [[MGSwipeButtonsView alloc] initWithButtons:_leftButtons direction:MGSwipeDirectionLeftToRight differentWidth:_allowsButtonsWithDifferentWidth];
        _leftView.view = self;
        _leftView.frame = CGRectMake(-_leftView.bounds.size.width, _leftSwipeSettings.topMargin, _leftView.bounds.size.width, _swipeOverlay.bounds.size.height - _leftSwipeSettings.topMargin - _leftSwipeSettings.bottomMargin);
        _leftView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        [_swipeOverlay addSubview:_leftView];
    }
    if (!_rightView && _rightButtons.count > 0) {
        _rightView = [[MGSwipeButtonsView alloc] initWithButtons:_rightButtons direction:MGSwipeDirectionRightToLeft differentWidth:_allowsButtonsWithDifferentWidth];
        _rightView.view = self;
        _rightView.frame = CGRectMake(_swipeOverlay.bounds.size.width, _rightSwipeSettings.topMargin, _rightView.bounds.size.width, _swipeOverlay.bounds.size.height - _rightSwipeSettings.topMargin - _rightSwipeSettings.bottomMargin);
        _rightView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
        [_swipeOverlay addSubview:_rightView];
    }
}


- (void) showSwipeOverlayIfNeeded
{
    if (_overlayEnabled) {
        return;
    }
    _overlayEnabled = YES;
	
    if (_swipeContentView)
        [_swipeContentView removeFromSuperview];
    if (_delegate && [_delegate respondsToSelector:@selector(swipeViewWillBeginSwiping:)]) {
        [_delegate swipeViewWillBeginSwiping:self];
    }
	_swipeView.image = [self imageFromView:self];
    _swipeOverlay.hidden = NO;
    if (_swipeContentView)
        [_swipeView addSubview:_swipeContentView];
    
    if (!_allowsMultipleSwipe) {
        //input overlay on the whole table

        if (_tableInputOverlay) {
            [_tableInputOverlay removeFromSuperview];
        }
        _tableInputOverlay = [[MGSwipeViewInputOverlay alloc] initWithFrame:self.superview.bounds];
        _tableInputOverlay.currentView = self;
        [self.superview addSubview:_tableInputOverlay];
    }
    
    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapHandler:)];
    _tapRecognizer.cancelsTouchesInView = YES;
    _tapRecognizer.delegate = self;
    [self addGestureRecognizer:_tapRecognizer];
}

-(void) hideSwipeOverlayIfNeeded
{
    if (!_overlayEnabled) {
        return;
    }
    _overlayEnabled = NO;
    _swipeOverlay.hidden = YES;
	_swipeView.image = nil;
    if (_swipeContentView) {
        [_swipeContentView removeFromSuperview];
        [self addSubview:_swipeContentView];
    }
    
    if (_tableInputOverlay) {
        [_tableInputOverlay removeFromSuperview];
        _tableInputOverlay = nil;
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(swipeViewWillEndSwiping:)]) {
        [_delegate swipeViewWillEndSwiping:self];
    }
    
    if (_tapRecognizer) {
        [self removeGestureRecognizer:_tapRecognizer];
        _tapRecognizer = nil;
    }
}

-(void) refreshContentView
{
    CGFloat currentOffset = _swipeOffset;
    BOOL prevValue = _triggerStateChanges;
    _triggerStateChanges = NO;
    self.swipeOffset = 0;
    self.swipeOffset = currentOffset;
    _triggerStateChanges = prevValue;
}

-(void) refreshButtons: (BOOL) usingDelegate
{
    if (usingDelegate) {
        self.leftButtons = @[];
        self.rightButtons = @[];
    }
    if (_leftView) {
        [_leftView removeFromSuperview];
        _leftView = nil;
    }
    if (_rightView) {
        [_rightView removeFromSuperview];
        _rightView = nil;
    }
    [self createSwipeViewIfNeeded];
    [self refreshContentView];
}

#pragma mark Handle Table Events

-(void) willMoveToSuperview:(UIView *)newSuperview;
{
    if (newSuperview == nil) { //remove the table overlay when a cell is removed from the table
        [self hideSwipeOverlayIfNeeded];
    }
}

-(UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!self.hidden && _swipeOverlay && !_swipeOverlay.hidden) {
        //override hitTest to give swipe buttons a higher priority (diclosure buttons can steal input)
        UIView * targets[] = {_leftView, _rightView};
        for (int i = 0; i< 2; ++i) {
            UIView * target = targets[i];
            if (!target) continue;
            
            CGPoint p = [self convertPoint:point toView:target];
            if (CGRectContainsPoint(target.bounds, p)) {
                return [target hitTest:p withEvent:event];
            }
        }
    }
    return [super hitTest:point withEvent:event];
}

#pragma mark Some utility methods

- (UIImage *)imageFromView:(UIView *)view {
	UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [[UIScreen mainScreen] scale]);
	[view.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage * image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return image;
}

-(UIColor *) backgroundColorForSwipe
{
    if (_swipeBackgroundColor) {
        return _swipeBackgroundColor; //user defined color
    }
    else if (self.backgroundColor && ![self.backgroundColor isEqual:[UIColor clearColor]]) {
        return self.backgroundColor;
    }
    return [UIColor lightGrayColor];
}

-(void) updateState: (MGSwipeState) newState;
{
    if (!_triggerStateChanges || _swipeState == newState) {
        return;
    }
    _swipeState = newState;
    if (_delegate && [_delegate respondsToSelector:@selector(swipeView:didChangeSwipeState:gestureIsActive:)]) {
        [_delegate swipeView:self didChangeSwipeState:_swipeState gestureIsActive: self.isSwipeGestureActive] ;
    }
}

#pragma mark Swipe Animation

- (void)setSwipeOffset:(CGFloat) newOffset;
{
    CGFloat sign = newOffset > 0 ? 1.0 : -1.0;
    MGSwipeButtonsView * activeButtons = sign < 0 ? _rightView : _leftView;
    MGSwipeSettings * activeSettings = sign < 0 ? _rightSwipeSettings : _leftSwipeSettings;
  
    if(activeSettings.enableSwipeBounces) {
        _swipeOffset = newOffset;
    }
    else {
        CGFloat maxOffset = sign * activeButtons.bounds.size.width;
        _swipeOffset = sign > 0 ? MIN(newOffset, maxOffset) : MAX(newOffset, maxOffset);
    }
    CGFloat offset = fabs(_swipeOffset);
  
  
    if (!activeButtons || offset == 0) {
        if (_leftView)
            [_leftView endExpansionAnimated:NO];
        if (_rightView)
            [_rightView endExpansionAnimated:NO];
        [self hideSwipeOverlayIfNeeded];
        _targetOffset = 0;
        [self updateState:MGSwipeStateNone];
        return;
    }
    else {
        [self showSwipeOverlayIfNeeded];
        CGFloat swipeThreshold = activeSettings.threshold;
        BOOL keepButtons = activeSettings.keepButtonsSwiped;
        _targetOffset = keepButtons && offset > activeButtons.bounds.size.width * swipeThreshold ? activeButtons.bounds.size.width * sign : 0;
    }
    
    BOOL onlyButtons = activeSettings.onlySwipeButtons;
	_swipeView.transform = CGAffineTransformMakeTranslation(onlyButtons ? 0 : _swipeOffset, 0);
	
    //animate existing buttons
    MGSwipeButtonsView* but[2] = {_leftView, _rightView};
    MGSwipeSettings* settings[2] = {_leftSwipeSettings, _rightSwipeSettings};
    MGSwipeExpansionSettings * expansions[2] = {_leftExpansion, _rightExpansion};
    
    for (int i = 0; i< 2; ++i) {
        MGSwipeButtonsView * view = but[i];
        if (!view) continue;

        //buttons view position
        CGFloat translation = MIN(offset, view.bounds.size.width) * sign + settings[i].offset * sign;
        view.transform = CGAffineTransformMakeTranslation(translation, 0);

        if (view != activeButtons) continue; //only transition if active (perf. improvement)
        bool expand = expansions[i].buttonIndex >= 0 && offset > view.bounds.size.width * expansions[i].threshold;
        if (expand) {
            [view expandToOffset:offset settings:expansions[i]];
            _targetOffset = expansions[i].fillOnTrigger ? self.bounds.size.width * sign : 0;
            _activeExpansion = view;
            [self updateState:i ? MGSwipeStateExpandingRightToLeft : MGSwipeStateExpandingLeftToRight];
        }
        else {
            [view endExpansionAnimated:YES];
            _activeExpansion = nil;
            CGFloat t = MIN(1.0f, offset/view.bounds.size.width);
            [view transition:settings[i].transition percent:t];
            [self updateState:i ? MGSwipeStateSwipingRightToLeft : MGSwipeStateSwipingLeftToRight];
        }
    }
}

-(void) hideSwipeAnimated: (BOOL) animated completion:(void(^)(BOOL finished)) completion
{
    MGSwipeAnimation * animation = animated ? (_swipeOffset > 0 ? _leftSwipeSettings.hideAnimation: _rightSwipeSettings.hideAnimation) : nil;
    [self setSwipeOffset:0 animation:animation completion:completion];
}

-(void) hideSwipeAnimated: (BOOL) animated
{
    [self hideSwipeAnimated:animated completion:nil];
}

-(void) showSwipe: (MGSwipeDirection) direction animated: (BOOL) animated
{
    [self showSwipe:direction animated:animated completion:nil];
}

-(void) showSwipe: (MGSwipeDirection) direction animated: (BOOL) animated completion:(void(^)(BOOL finished)) completion
{
    [self createSwipeViewIfNeeded];
    _allowSwipeLeftToRight = _leftButtons.count > 0;
    _allowSwipeRightToLeft = _rightButtons.count > 0;
    UIView * buttonsView = direction == MGSwipeDirectionLeftToRight ? _leftView : _rightView;
    
    if (buttonsView) {
        CGFloat s = direction == MGSwipeDirectionLeftToRight ? 1.0 : -1.0;
        MGSwipeAnimation * animation = animated ? (direction == MGSwipeDirectionLeftToRight ? _leftSwipeSettings.showAnimation : _rightSwipeSettings.showAnimation) : nil;
        [self setSwipeOffset:buttonsView.bounds.size.width * s animation:animation completion:completion];
    }
}

-(void) expandSwipe: (MGSwipeDirection) direction animated: (BOOL) animated
{
    CGFloat s = direction == MGSwipeDirectionLeftToRight ? 1.0 : -1.0;
    MGSwipeExpansionSettings* expSetting = direction == MGSwipeDirectionLeftToRight ? _leftExpansion : _rightExpansion;
    
    // only perform animation if there's no pending expansion animation and requested direction has fillOnTrigger enabled
    if(!_activeExpansion && expSetting.fillOnTrigger) {
        [self createSwipeViewIfNeeded];
        _allowSwipeLeftToRight = _leftButtons.count > 0;
        _allowSwipeRightToLeft = _rightButtons.count > 0;
        UIView * buttonsView = direction == MGSwipeDirectionLeftToRight ? _leftView : _rightView;
        
        if (buttonsView) {
            __weak MGSwipeButtonsView * expansionView = direction == MGSwipeDirectionLeftToRight ? _leftView : _rightView;
            __weak MGSwipeView * weakself = self;
            [self setSwipeOffset:buttonsView.bounds.size.width * s * expSetting.threshold * 2 animation:expSetting.triggerAnimation completion:^(BOOL finished){
                [expansionView endExpansionAnimated:YES];
                [weakself setSwipeOffset:0 animated:NO completion:nil];
            }];
        }
    }
}

-(void) animationTick: (CADisplayLink *) timer
{
    if (!_animationData.start) {
        _animationData.start = timer.timestamp;
    }
    CFTimeInterval elapsed = timer.timestamp - _animationData.start;
    bool completed = elapsed >= _animationData.duration;
    if (completed) {
        _triggerStateChanges = YES;
    }
    self.swipeOffset = [_animationData.animation value:elapsed duration:_animationData.duration from:_animationData.from to:_animationData.to];
    
    //call animation completion and invalidate timer
    if (completed){
        [timer invalidate];
        _displayLink = nil;
        if (_animationCompletion) {
            void (^callbackCopy)(BOOL finished) = _animationCompletion; //copy to avoid duplicated callbacks
            _animationCompletion = nil;
            callbackCopy(YES);
        }
    }
}
-(void) setSwipeOffset:(CGFloat)offset animated: (BOOL) animated completion:(void(^)(BOOL finished)) completion
{
    MGSwipeAnimation * animation = animated ? [[MGSwipeAnimation alloc] init] : nil;
    [self setSwipeOffset:offset animation:animation completion:completion];
}

-(void) setSwipeOffset:(CGFloat)offset animation: (MGSwipeAnimation *) animation completion:(void(^)(BOOL finished)) completion
{
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    if (_animationCompletion) { //notify previous animation cancelled
        void (^callbackCopy)(BOOL finished) = _animationCompletion; //copy to avoid duplicated callbacks
        _animationCompletion = nil;
        callbackCopy(NO);
    }
    if (offset !=0) {
        [self createSwipeViewIfNeeded];
    }
    
    if (!animation) {
        self.swipeOffset = offset;
        if (completion) {
            completion(YES);
        }
        return;
    }
    
    _animationCompletion = completion;
    _triggerStateChanges = NO;
    _animationData.from = _swipeOffset;
    _animationData.to = offset;
	_animationData.duration = animation.duration;
    _animationData.start = 0;
    _animationData.animation = animation;
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animationTick:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

#pragma mark Gestures

-(void) cancelPanGesture
{
    if (_panRecognizer.state != UIGestureRecognizerStateEnded && _panRecognizer.state != UIGestureRecognizerStatePossible) {
        _panRecognizer.enabled = NO;
        _panRecognizer.enabled = YES;
        if (self.swipeOffset) {
            [self hideSwipeAnimated:YES];
        }
    }
}

-(void) tapHandler: (UITapGestureRecognizer *) recognizer
{
    BOOL hide = YES;
    if (_delegate && [_delegate respondsToSelector:@selector(swipeView:shouldHideSwipeOnTap:)]) {
        hide = [_delegate swipeView:self shouldHideSwipeOnTap:[recognizer locationInView:self]];
    }
    if (hide) {
        [self hideSwipeAnimated:YES];
    }
}

-(CGFloat) filterSwipe: (CGFloat) offset
{
    bool allowed = offset > 0 ? _allowSwipeLeftToRight : _allowSwipeRightToLeft;
    UIView * buttons = offset > 0 ? _leftView : _rightView;
    if (!buttons || ! allowed) {
        offset = 0;
    }
    else if (!_allowsOppositeSwipe && _firstSwipeState == MGSwipeStateSwipingLeftToRight && offset < 0) {
        offset = 0;
    }
    else if (!_allowsOppositeSwipe && _firstSwipeState == MGSwipeStateSwipingRightToLeft && offset > 0 ) {
        offset = 0;
    }
    return offset;
}

-(void) panHandler: (UIPanGestureRecognizer *)gesture
{
    CGPoint current = [gesture translationInView:self];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
		[_rnGestureRecognizers makeObjectsPerformSelector:NSSelectorFromString(@"cancel")];
		
        [self createSwipeViewIfNeeded];
        _panStartPoint = current;
        _panStartOffset = _swipeOffset;
        if (_swipeOffset != 0) {
            _firstSwipeState = _swipeOffset > 0 ? MGSwipeStateSwipingLeftToRight : MGSwipeStateSwipingRightToLeft;
        }
        
        if (!_allowsMultipleSwipe) {
            NSArray * views = self.superview.subviews;
            for (MGSwipeView * view in views) {
                if ([view isKindOfClass:[MGSwipeView class]] && view != self) {
                    [view cancelPanGesture];
                }
            }
        }
    }
    else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat offset = _panStartOffset + current.x - _panStartPoint.x;
        if (_firstSwipeState == MGSwipeStateNone) {
            _firstSwipeState = offset > 0 ? MGSwipeStateSwipingLeftToRight : MGSwipeStateSwipingRightToLeft;
        }
        self.swipeOffset = [self filterSwipe:offset];
    }
    else {
        MGSwipeButtonsView * expansion = _activeExpansion;
        if (expansion) {
            UIView * expandedButton = [expansion getExpandedButton];
            MGSwipeExpansionSettings * expSettings = _swipeOffset > 0 ? _leftExpansion : _rightExpansion;
            UIColor * backgroundColor = nil;
            if (!expSettings.fillOnTrigger && expSettings.expansionColor) {
                backgroundColor = expansion.backgroundColorCopy; //keep expansion background color
                expansion.backgroundColorCopy = expSettings.expansionColor;
            }
            [self setSwipeOffset:_targetOffset animation:expSettings.triggerAnimation completion:^(BOOL finished){
                if (!finished || self.hidden) {
                    return; //cell might be hidden after a delete row animation without being deallocated (to be reused later)
                }
                BOOL autoHide = [expansion handleClick:expandedButton fromExpansion:YES];
                if (autoHide) {
                    [expansion endExpansionAnimated:NO];
                }
                if (backgroundColor) {
                    expandedButton.backgroundColor = backgroundColor;
                }
            }];
        }
        else {
            CGFloat velocity = [_panRecognizer velocityInView:self].x;
            CGFloat inertiaThreshold = 100.0; //points per second
            
            if (velocity > inertiaThreshold) {
                _targetOffset = _swipeOffset < 0 ? 0 : (_leftView  && _leftSwipeSettings.keepButtonsSwiped ? _leftView.bounds.size.width : _targetOffset);
            }
            else if (velocity < -inertiaThreshold) {
                _targetOffset = _swipeOffset > 0 ? 0 : (_rightView && _rightSwipeSettings.keepButtonsSwiped ? -_rightView.bounds.size.width : _targetOffset);
            }
            _targetOffset = [self filterSwipe:_targetOffset];
            MGSwipeSettings * settings = _swipeOffset > 0 ? _leftSwipeSettings : _rightSwipeSettings;
            MGSwipeAnimation * animation = nil;
            if (_targetOffset == 0) {
                animation = settings.hideAnimation;
            }
            else if (fabs(_swipeOffset) > fabs(_targetOffset)) {
                animation = settings.stretchAnimation;
            }
            else {
                animation = settings.showAnimation;
            }
            [self setSwipeOffset:_targetOffset animation:animation completion:nil];
        }
        
        _firstSwipeState = MGSwipeStateNone;
    }
	
	if(gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled)
	{
		[_rnGestureRecognizers removeAllObjects];
	}
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	if([otherGestureRecognizer isKindOfClass:NSClassFromString(@"RCTTouchHandler")])
	{
		if(_rnGestureRecognizers == nil)
		{
			_rnGestureRecognizers = [NSMutableSet new];
		}
		
		[_rnGestureRecognizers addObject:otherGestureRecognizer];
	}
	
	return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    
    if (gestureRecognizer == _panRecognizer) {
        
        CGPoint translation = [_panRecognizer translationInView:self];
        if (fabs(translation.y) > fabs(translation.x)) {
            return NO; // user is scrolling vertically
        }
        if (_swipeView) {
            CGPoint point = [_tapRecognizer locationInView:_swipeView];
            if (!CGRectContainsPoint(_swipeView.bounds, point)) {
                return _allowsSwipeWhenTappingButtons; //user clicked outside the cell or in the buttons area
            }
        }
        
        if (_swipeOffset != 0.0) {
            return YES; //already swiped, don't need to check buttons or canSwipe delegate
        }
        
        //make a decision according to existing buttons or using the optional delegate
        if (_delegate && [_delegate respondsToSelector:@selector(swipeView:canSwipe:fromPoint:)]) {
            CGPoint point = [_panRecognizer locationInView:self];
            _allowSwipeLeftToRight = [_delegate swipeView:self canSwipe:MGSwipeDirectionLeftToRight fromPoint:point];
            _allowSwipeRightToLeft = [_delegate swipeView:self canSwipe:MGSwipeDirectionRightToLeft fromPoint:point];
        }
        else if (_delegate && [_delegate respondsToSelector:@selector(swipeView:canSwipe:)]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _allowSwipeLeftToRight = [_delegate swipeView:self canSwipe:MGSwipeDirectionLeftToRight];
            _allowSwipeRightToLeft = [_delegate swipeView:self canSwipe:MGSwipeDirectionRightToLeft];
            #pragma clang diagnostic pop
        }
        else {
            [self fetchButtonsIfNeeded];
            _allowSwipeLeftToRight = _leftButtons.count > 0;
            _allowSwipeRightToLeft = _rightButtons.count > 0;
        }
        
        return (_allowSwipeLeftToRight && translation.x > 0) || (_allowSwipeRightToLeft && translation.x < 0);
    }
    else if (gestureRecognizer == _tapRecognizer) {
        CGPoint point = [_tapRecognizer locationInView:_swipeView];
        return CGRectContainsPoint(_swipeView.bounds, point);
    }
    return YES;
}

-(BOOL) isSwipeGestureActive
{
    return _panRecognizer.state == UIGestureRecognizerStateBegan || _panRecognizer.state == UIGestureRecognizerStateChanged;
}

-(void)setSwipeBackgroundColor:(UIColor *)swipeBackgroundColor {
    _swipeBackgroundColor = swipeBackgroundColor;
    if (_swipeOverlay) {
        _swipeOverlay.backgroundColor = swipeBackgroundColor;
    }
}

#pragma mark Accessibility

- (NSInteger)accessibilityElementCount {
    return _swipeOffset == 0 ? [super accessibilityElementCount] : 1;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return _swipeOffset == 0  ? [super accessibilityElementAtIndex:index] : self;
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return _swipeOffset == 0  ? [super indexOfAccessibilityElement:element] : 0;
}


@end