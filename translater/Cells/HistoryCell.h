//
//  HistoryCell.h
//  translater
//
//  Created by sambo on 03.07.17.
//  Copyright © 2017 admin. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TranslateEntity;

@interface HistoryCell : UITableViewCell

- (void)showHistory:(TranslateEntity*)translateEntity;

@end
