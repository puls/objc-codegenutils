# objc-assetgen

Xcode 5 has an awesome new feature called "[asset catalogs](https://developer.apple.com/technologies/tools/features.html)", allowing you to specify all of your image variants and resizable cap insets in a single place.

Unfortunately, to get the full benefits, you have to set your deployment target to iOS 7; otherwise, Xcode will dutifully put all of the images into your app bundle but totally ignore all of your resizable insets with only a build warning.

But shucks! The important and awesome part is the editor, and it puts all of the data out in super-readable JSON. We should be able to do a poor man's version that reads in the data and spits out some code to give you most of the benefits.

## Usage

Call `objc-assetgen` with the `.xcassets` paths as arguments from the directory into which it should output the code.

For an asset catalog named "Foo" containing image sets "Bar" and "Baz", you'll get `WQFooCatalog.h` and `WQFooCatalog.m`, with class methods `+ (UIImage *)imageForBar` and `+ (UIImage *)imageForBaz`. Put them in your DerivedSources folder and you're good to go.

## Command-line options

There are none. The class prefix is hardcoded as `WQ` and the output directory is hardcoded as the current one. We should fix this.

## Future plans

Maybe swizzle `+[UIImage imageNamed:]`?