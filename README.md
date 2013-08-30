# objc-assetgen

Xcode 5 has an awesome new feature called "[asset catalogs](https://developer.apple.com/technologies/tools/features.html)", allowing you to specify all of your image variants and resizable cap insets in a single place.

Unfortunately, to get the full benefits, you have to set your deployment target to iOS 7; otherwise, Xcode will dutifully put all of the images into your app bundle but totally ignore all of your resizable insets with only a build warning.

But shucks! The important and awesome part is the editor, and it puts all of the data out in super-readable JSON. We should be able to do a poor man's version that reads in the data and spits out some code to give you most of the benefits.

## Usage

Call `objc-assetgen` with the `.xcassets` paths as arguments from the directory into which it should output the code.

For an asset catalog named "Foo" containing image sets "Bar" and "Baz", you'll get `FooCatalog.h` and `FooCatalog.m`, with class methods `+ (UIImage *)imageForBar` and `+ (UIImage *)imageForBaz`. Put them in your DerivedSources folder and you're good to go.

## Command-line options

Usage:
* `objc-assetgen [-o <path>] [-f <path>] [-p <prefix>] [<paths>]`
* `objc-assetgen -h`

Options:
<dl>
<dt><code>-o &lt;path></code></dt><dd>Output files at <code>&lt;path></code></dd>
<dt><code>-f &lt;path></code></dt><dd>Search for *.xcassets folders starting from <code>&lt;path></code></dd>
<dt><code>-p &lt;prefix></code></dt><dd>Use <code>&lt;prefix></code> as the class prefix in the generated code</dd>
<dt><code>-h</code></dt><dd>Print this help and exit</dd>
<dt><code>&lt;paths></code></dt><dd>Input files; this and/or -f are required.</dd>
</dl>
