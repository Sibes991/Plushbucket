# Adds the Plushbucket Apple Watch app to the iPhone project that Capacitor generates (ios/App/App.xcodeproj).
# GitHub runs this on every iPhone build, after `npx cap sync ios`, through watch/add-to-ios.sh.
# Usage: ruby watch/add-watch-target.rb ios/App/App.xcodeproj
require 'xcodeproj'

project_path = ARGV[0] or abort 'usage: ruby add-watch-target.rb path/to/App.xcodeproj'
NAME = 'PlushbucketWatch'
APP_ID = 'com.plushbucket.app'
WATCH_ID = "#{APP_ID}.watchkitapp"
WATCHOS = '10.0'

project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == 'App' } or abort 'No App target in the project'

# The iPhone app keeps its own bundle ID here, so the build command doesn't have to set it for every target
app.build_configurations.each { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = APP_ID }

if project.targets.any? { |t| t.name == NAME }
  puts "#{NAME} is already in the project"
  project.save
  exit 0
end

watch = project.new_target(:application, NAME, :watchos, WATCHOS, nil, :swift)
# Swift links Foundation by itself; drop the SDK-versioned framework reference new_target adds
watch.frameworks_build_phase.files.to_a.each(&:remove_from_project)

watch.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = WATCH_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = 'Plushbucket'
  s['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = APP_ID
  s['INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp'] = 'NO'
  s['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown'
  s['SDKROOT'] = 'watchos'
  s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['WATCHOS_DEPLOYMENT_TARGET'] = WATCHOS
  s['SWIFT_VERSION'] = '5.0'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SKIP_INSTALL'] = 'YES'        # it ships inside the iPhone app, not as its own archive
  s['MARKETING_VERSION'] ||= '1.0' # the build command sets the real version and build number for both apps
  s['CURRENT_PROJECT_VERSION'] ||= '1'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
end

# Source files and the asset catalog (copied next to App.xcodeproj by add-to-ios.sh)
group = project.main_group.new_group(NAME, NAME)
src = File.join(File.dirname(project_path), NAME)
Dir.children(src).sort.each do |f|
  next if f.start_with?('.')
  ref = group.new_reference(f)
  if f.end_with?('.swift')
    watch.source_build_phase.add_file_reference(ref, true)
  elsif f.end_with?('.xcassets')
    watch.resources_build_phase.add_file_reference(ref, true)
  end
end

# Embed the watch app inside the iPhone app (Plushbucket.app/Watch/PlushbucketWatch.app) and build it first
embed = app.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' } || app.new_copy_files_build_phase('Embed Watch Content')
embed.dst_subfolder_spec = '16'
embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
embed.add_file_reference(watch.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.add_dependency(watch)

project.save
puts "Added #{NAME} (#{WATCH_ID}, watchOS #{WATCHOS}+) to #{project_path}"
