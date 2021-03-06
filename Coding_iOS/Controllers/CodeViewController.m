//
//  CodeViewController.m
//  Coding_iOS
//
//  Created by 王 原闯 on 14/10/30.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#import "CodeViewController.h"
#import "Coding_NetAPIManager.h"
#import "WebContentManager.h"
#import "ProjectCommitsViewController.h"
#import "ProjectViewController.h"
#import "CodeListViewController.h"
#import "EditCodeViewController.h"

@interface CodeViewController ()
@property (strong, nonatomic) UIWebView *webContentView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@end

@implementation CodeViewController

+ (CodeViewController *)codeVCWithProject:(Project *)project andCodeFile:(CodeFile *)codeFile{
    CodeViewController *vc = [[CodeViewController alloc] init];
    vc.myProject = project;
    vc.myCodeFile = codeFile;
    return vc;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = kColorTableBG;
    self.title = self.isReadMe? @"README": [[_myCodeFile.path componentsSeparatedByString:@"/"] lastObject];
    
    {//用webView显示内容
        _webContentView = [[UIWebView alloc] initWithFrame:self.view.bounds];
        _webContentView.delegate = self;
        _webContentView.backgroundColor = [UIColor clearColor];
        _webContentView.opaque = NO;
        _webContentView.scalesPageToFit = YES;
        [self.view addSubview:_webContentView];
        //webview加载指示
        _activityIndicator = [[UIActivityIndicatorView alloc]
                              initWithActivityIndicatorStyle:
                              UIActivityIndicatorViewStyleGray];
        _activityIndicator.hidesWhenStopped = YES;
        [_activityIndicator setCenter:CGPointMake(CGRectGetWidth(_webContentView.frame)/2, CGRectGetHeight(_webContentView.frame)/2)];
        [_webContentView addSubview:_activityIndicator];
        [_webContentView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];
    }
    [self sendRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Orientations
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark Request

- (void)sendRequest{
    [self.view beginLoading];
    __weak typeof(self) weakSelf = self;
    if (_isReadMe) {
        [[Coding_NetAPIManager sharedManager] request_ReadMeOFProject:_myProject andBlock:^(id data, NSError *error) {
            [weakSelf doSomethingWithResponse:data andError:error];
        }];
    }else{
        [[Coding_NetAPIManager sharedManager] request_CodeFile:_myCodeFile withPro:_myProject andBlock:^(id data, NSError *error) {
            [weakSelf doSomethingWithResponse:data andError:error];
        }];
    }
}

- (void)doSomethingWithResponse:(id)data andError:(NSError *)error{
    [self.view endLoading];
    if ([data isKindOfClass:[CodeFile class]]) {
        self.myCodeFile = data;
        [self refreshCodeViewData];
    }else{
        self.myCodeFile = [CodeFile codeFileWithMDPreview:data];
        [self refreshCodeViewData];
    }
    BOOL hasError = (error != nil && error.code != 1204);//depot_has_no_commit
    [self.view configBlankPage:EaseBlankPageTypeCode hasData:(data != nil) hasError:hasError reloadButtonBlock:^(id sender) {
        [self sendRequest];
    }];
    self.webContentView.hidden = hasError;
    [self configRightNavBtn];
}

- (void)refreshCodeViewData{
    if ([_myCodeFile.file.mode isEqualToString:@"image"]) {
//        NSURL *imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@u/%@/p/%@/git/raw/%@", [NSObject baseURLStr], _myProject.owner_user_name, _myProject.name, [NSString handelRef:_myCodeFile.ref path:_myCodeFile.file.path]]];
        NSURL *imageUrl;
        if (kTarget_Enterprise) {//企业版不需要 owner_user_name
            imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@p/%@/git/raw/%@/%@", [NSObject baseURLStr], _myProject.name, _myCodeFile.ref, _myCodeFile.file.path]];
        }else{
            imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@u/%@/p/%@/git/raw/%@/%@", [NSObject baseURLStr], _myProject.owner_user_name, _myProject.name, _myCodeFile.ref, _myCodeFile.file.path]];
        }
        DebugLog(@"imageUrl: %@", imageUrl);
        [self.webContentView loadRequest:[NSURLRequest requestWithURL:imageUrl]];
    }else if ([@[@"file", @"sym_link", @"executable"] containsObject:_myCodeFile.file.mode]){
        NSString *contentStr = [WebContentManager codePatternedWithContent:_myCodeFile isEdit:NO];
        [self.webContentView loadHTMLString:contentStr baseURL:[NSURL URLWithString:[self p_baseHref]]];
    }
}

- (NSString *)p_baseHref{//写在 html 文件里的，没有 baseHref 的话，锚点会异常
    return @"https://coding.net/";
}

#pragma mark UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    DebugLog(@"strLink=[%@]",request.URL.absoluteString);
    if ([_myCodeFile.file.mode isEqualToString:@"image"]) {
        NSString *imageStr;
        if (kTarget_Enterprise) {
            imageStr = [NSString stringWithFormat:@"%@p/%@/git/raw/%@/%@", [NSObject baseURLStr], _myProject.name, _myCodeFile.ref, _myCodeFile.file.path];
        }else{
            imageStr = [NSString stringWithFormat:@"%@u/%@/p/%@/git/raw/%@/%@", [NSObject baseURLStr], _myProject.owner_user_name, _myProject.name, _myCodeFile.ref, _myCodeFile.file.path];
        }
        if ([imageStr isEqualToString:request.URL.absoluteString]) {
            return YES;
        }
    }
    if ([request.URL.absoluteString isEqualToString:[self p_baseHref]] ||
        [request.URL.absoluteString hasPrefix:[[self p_baseHref] stringByAppendingString:@"#"]]) {
        return YES;
    }
    UIViewController *vc = [BaseViewController analyseVCFromLinkStr:request.URL.absoluteString];
    if (vc) {
        [self.navigationController pushViewController:vc animated:YES];
        return NO;
    }
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView{
    [_activityIndicator startAnimating];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    [_activityIndicator stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    if([error code] == NSURLErrorCancelled)
        return;
    else
        DebugLog(@"%@", error.description);
}

#pragma mark Nav
- (void)configRightNavBtn{
    if (!self.navigationItem.rightBarButtonItem) {
        if (_isReadMe) {
            if (self.myCodeFile.can_edit) {
                [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"tweetBtn_Nav"] style:UIBarButtonItemStylePlain target:self action:@selector(goToEditVC)] animated:NO];
            }else{
                [self.navigationItem setRightBarButtonItem:nil animated:NO];
            }
        }else{
            [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"moreBtn_Nav"] style:UIBarButtonItemStylePlain target:self action:@selector(rightNavBtnClicked)] animated:NO];
        }
    }
}

- (void)rightNavBtnClicked{
    NSMutableArray *actionTitles = @[@"编辑代码", @"查看提交记录", @"退出代码查看"].mutableCopy;
    if (!self.myCodeFile.can_edit || [self.myCodeFile.file.mode isEqualToString:@"image"]) {
        [actionTitles removeObjectAtIndex:0];
    }
    __weak typeof(self) weakSelf = self;
    [[UIAlertController ea_actionSheetCustomWithTitle:nil buttonTitles:actionTitles destructiveTitle:self.myCodeFile.can_edit? @"删除文件": nil cancelTitle:@"取消" andDidDismissBlock:^(UIAlertAction *action, NSInteger index) {
        [weakSelf actionSheetClickedIndex:index];
    }] showInView:self.view];
}

- (void)actionSheetClickedIndex:(NSInteger)index{
    if (!self.myCodeFile.can_edit || [self.myCodeFile.file.mode isEqualToString:@"image"]) {
        index++;
    }
    if (index == 0) {
        [self goToEditVC];
    }else if (index == 1){
        [self goToCommitsVC];
    }else if (index == 2){
        [self popOut];
    }else if (index == 3 && self.myCodeFile.can_edit){
        [self deleteBtnClicked];
    }
}

- (void)deleteBtnClicked{
    __weak typeof(self) weakSelf = self;
    [[UIAlertController ea_actionSheetCustomWithTitle:[NSString stringWithFormat:@"确定要删除文件 %@ 吗？", _myCodeFile.file.name] buttonTitles:nil destructiveTitle:@"确认删除" cancelTitle:@"取消" andDidDismissBlock:^(UIAlertAction *action, NSInteger index) {
        if (index == 0) {
            [weakSelf sendDeleteRequst];
        }
    }] showInView:self.view];
}

- (void)sendDeleteRequst{
    [NSObject showHUDQueryStr:@"正在删除..."];
    [[Coding_NetAPIManager sharedManager] request_DeleteCodeFile:_myCodeFile withPro:_myProject andBlock:^(id data, NSError *error) {
        [NSObject hideHUDQuery];
        if (data) {
            //            if (self.savedSucessBlock) {
            //                self.savedSucessBlock();
            //            }
            [self.navigationController popViewControllerAnimated:YES];
        }
    }];
}

- (void)goToEditVC{
    __weak typeof(self) weakSelf = self;

    EditCodeViewController *vc = [EditCodeViewController new];
    vc.myProject = _myProject;
    vc.myCodeFile = _myCodeFile;
    vc.savedSucessBlock = ^{
        [weakSelf sendRequest];
    };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)goToCommitsVC{
    ProjectCommitsViewController *vc = [ProjectCommitsViewController new];
    vc.curProject = self.myProject;
    vc.curCommits = [Commits commitsWithRef:self.myCodeFile.ref Path:self.myCodeFile.path];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)popOut{
    __weak typeof(self) weakSelf = self;
    [self.navigationController.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIViewController *obj, NSUInteger idx, BOOL *stop) {
        if (![obj isKindOfClass:[CodeViewController class]] &&
            ![obj isKindOfClass:[CodeListViewController class]] &&
            !([obj isKindOfClass:[ProjectViewController class]] && [(ProjectViewController *)obj curType] == ProjectViewTypeCodes)) {
            *stop = YES;
            [weakSelf.navigationController popToViewController:obj animated:YES];
        }
    }];
}

@end
