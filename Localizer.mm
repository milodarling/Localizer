#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTextFieldSpecifier.h>
#import <Preferences/PSTableCellType.h>
#import <MessageUI/MFMailComposeViewController.h>
#import <objc/runtime.h>

static NSString *const kSourcePath = @"/Library/Localizer/FilesToLocalize";
static NSString *const kOutputPath = @"/Library/Localizer/TranslatedFiles/";
static NSString *const kTweakPreferencePath = @"/var/mobile/Library/Preferences/com.milodarling.localizer.plist";

@interface LocalizerListController : PSListController {
}
@end

@interface LocalizerStringsEditor : PSListController <MFMailComposeViewControllerDelegate> {
	NSString *filename;
	NSMutableDictionary *translated;
	UIAlertView *hud;
}
@end

@implementation LocalizerListController
- (id)specifiers {
	if(_specifiers == nil) {
		NSMutableArray *specifiers = [NSMutableArray new];
		NSArray *fileHolderArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kSourcePath error:NULL];
		[fileHolderArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSString *filename = (NSString *)obj;
			NSLog(@"Got %@", filename);
			//NSString *path = [kSourcePath stringByAppendingPathComponent:filename];
			//NSString *extension = [filename pathExtension];
			//NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:path];
			PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:[filename stringByDeletingPathExtension]
				target:self
				set:NULL
				get:NULL
				detail:objc_getClass("LocalizerStringsEditor")
				cell:PSLinkCell
				edit:Nil];
			[spec setProperty:filename forKey:@"filename"];
			[specifiers addObject:spec];
		}];
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
@end

@implementation LocalizerStringsEditor

-(id)init {
	if (self=[super init]) {
		translated = [NSMutableDictionary new];
	}
	return self;
}

-(void)setSpecifier:(PSSpecifier *)specifier {
	[super setSpecifier:specifier];
	filename = specifier.properties[@"filename"];
	translated = [[NSDictionary dictionaryWithContentsOfFile:kTweakPreferencePath] objectForKey:@"filename"];
}

-(id)specifiers {
	if (_specifiers == nil) {
		NSMutableArray *specifiers = [NSMutableArray new];
		NSString *localizableFile = [kSourcePath stringByAppendingPathComponent:filename];
		NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:localizableFile];
		PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:@"Language"
				target:self
				set:@selector(setLanguage:specifier:)
				get:@selector(getLanguage:)
				detail:Nil
				cell:PSEditTextCell
				edit:Nil];
		[specifiers addObject:spec];
		NSLog(@"localizableFile: %@, dict: %@", localizableFile, dict);
		for (NSString *key in dict) {
			if ([key isEqualToString:@"LocalizerDevEmail"])
				continue;
			spec = [PSSpecifier groupSpecifierWithHeader:key footer:dict[key]];
			[specifiers addObject:spec];
			PSTextFieldSpecifier *textSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@""
				target:self
				set:@selector(setPreferenceValue:specifier:)
				get:@selector(readPreferenceValue:)
				detail:Nil
				cell:PSEditTextCell
				edit:Nil];
			[textSpec setProperty:key forKey:@"key"];
			[specifiers addObject:textSpec];
		}
		spec = [PSSpecifier groupSpecifierWithHeader:@"" footer:@"Save the file to /Library/Localizer/TranslatedFiles/. After that, you can upload it somewhere or do whatever you want with it!"];
		[specifiers addObject:spec];
		spec = spec = [PSSpecifier preferenceSpecifierNamed:@"Save file"
				target:self
				set:NULL
				get:NULL
				detail:Nil
				cell:PSButtonCell
				edit:Nil];
		spec->action = @selector(saveFile);
		[specifiers addObject:spec];
		if (dict[@"LocalizerDevEmail"]) {
			spec = [PSSpecifier groupSpecifierWithHeader:@"" footer:@"Email the dev your translated .strings file!"];
			[specifiers addObject:spec];
			spec = [PSSpecifier preferenceSpecifierNamed:@"Email Developer"
				target:self
				set:NULL
				get:NULL
				detail:Nil
				cell:PSButtonCell
				edit:Nil];
			[spec setProperty:dict[@"LocalizerDevEmail"] forKey:@"email"];
			spec->action = @selector(emailDev:);
			[specifiers addObject:spec];
		}
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}

-(void)setLanguage:(id)value specifier:(PSSpecifier *)specifier {
	NSMutableDictionary *preferences = [NSMutableDictionary new];
	[preferences addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:kTweakPreferencePath]];
	[preferences setObject:value forKey:[filename stringByAppendingString:@"-language"]];
	[preferences writeToFile:kTweakPreferencePath atomically:YES];
}

-(id)getLanguage:(PSSpecifier *)specifier {
	return [[NSDictionary dictionaryWithContentsOfFile:kTweakPreferencePath] objectForKey:[filename stringByAppendingString:@"-language"]];
}

-(void)emailDev:(PSSpecifier *)specifier {
	[self.view endEditing:YES];
	NSDictionary *properties = [specifier properties];
	MFMailComposeViewController *emailDev = [[MFMailComposeViewController alloc] init];
    [emailDev setSubject:@"Translated Strings"];
    [emailDev setToRecipients:@[properties[@"email"]]];
    [emailDev setMessageBody:[NSString stringWithFormat:@"Language: %@", [self getLanguage:nil]] isHTML:NO];
    NSError *error = nil;
    NSData *plistToSend = [NSPropertyListSerialization dataWithPropertyList:translated
                          format:NSPropertyListXMLFormat_v1_0
                         options:0
                           error:&error];
    [emailDev addAttachmentData:plistToSend mimeType:@"application/xml" fileName:@"Localizable.strings"];
    [self.navigationController presentViewController:emailDev animated:YES completion:nil];
    emailDev.mailComposeDelegate = self;
}

-(void)saveFile {
	[self.view endEditing:YES];
	NSString *pathToWrite = [kOutputPath stringByAppendingPathComponent:filename];
	[translated writeToFile:pathToWrite atomically:YES];
	hud = [[UIAlertView alloc] initWithTitle:@"✓ Done!"
											  message:nil
											 delegate:nil
									cancelButtonTitle:nil
									otherButtonTitles:nil];
	[hud show];
	[self performSelector:@selector(dismissHUD) withObject:nil afterDelay:0.2f];
}

-(void)dismissHUD {
	[hud dismissWithClickedButtonIndex:0 animated:YES];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissViewControllerAnimated: YES completion: nil];
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	[translated setObject:value forKey:[specifier propertyForKey:@"key"]];
	NSMutableDictionary *preferences = [NSMutableDictionary new];
	[preferences addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:kTweakPreferencePath]];
	[preferences setObject:translated forKey:filename];
	[preferences writeToFile:kTweakPreferencePath atomically:YES];
}

-(id)readPreferenceValue:(PSSpecifier *)specifier {
	return [translated objectForKey:[specifier propertyForKey:@"key"]];
}

@end

// vim:ft=objc
