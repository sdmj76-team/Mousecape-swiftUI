#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Mousecape/Mousecape.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the mousecloak target
mousecloak_target = project.targets.find { |t| t.name == 'mousecloak' }

if mousecloak_target.nil?
  puts "Error: mousecloak target not found"
  exit 1
end

puts "Found mousecloak target"

# Find the main group
mousecloak_group = project.main_group.groups.find { |g| g.name == 'mousecloak' || g.path == 'mousecloak' }

if mousecloak_group.nil?
  puts "Error: mousecloak group not found"
  exit 1
end

puts "Found mousecloak group"

# Remove main.m from the project
main_m_ref = mousecloak_group.files.find { |f| f.path == 'main.m' }
if main_m_ref
  puts "Removing main.m from project"
  main_m_ref.remove_from_project

  # Remove from build phases
  mousecloak_target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == main_m_ref
      build_file.remove_from_project
    end
  end
end

# Add main.swift to the project
main_swift_ref = mousecloak_group.files.find { |f| f.path == 'main.swift' }
if main_swift_ref.nil?
  puts "Adding main.swift to project"
  main_swift_ref = mousecloak_group.new_file('Mousecape/mousecloak/main.swift')
  mousecloak_target.add_file_references([main_swift_ref])
else
  puts "main.swift already in project"
end

# Add bridging header to the project
bridging_header_ref = mousecloak_group.files.find { |f| f.path == 'mousecloak-Bridging-Header.h' }
if bridging_header_ref.nil?
  puts "Adding mousecloak-Bridging-Header.h to project"
  bridging_header_ref = mousecloak_group.new_file('Mousecape/mousecloak/mousecloak-Bridging-Header.h')
else
  puts "mousecloak-Bridging-Header.h already in project"
end

# Configure build settings
puts "Configuring build settings"
mousecloak_target.build_configurations.each do |config|
  config.build_settings['SWIFT_OBJC_BRIDGING_HEADER'] = 'Mousecape/mousecloak/mousecloak-Bridging-Header.h'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
end

# Note: Swift Package Manager dependencies need to be added manually in Xcode
puts "Note: Swift ArgumentParser package dependency needs to be added manually in Xcode"
puts "  Package URL: https://github.com/apple/swift-argument-parser"
puts "  Version: 1.2.0 or later"

# Save the project
puts "Saving project"
project.save

puts "Done! Project configured successfully."
puts ""
puts "Next steps:"
puts "1. Open Mousecape.xcodeproj in Xcode"
puts "2. Add Swift ArgumentParser package dependency:"
puts "   - File → Add Package Dependencies..."
puts "   - URL: https://github.com/apple/swift-argument-parser"
puts "   - Version: 1.2.0 or later"
puts "   - Add to mousecloak target"
puts "3. Delete Mousecape/mousecloak/main.m manually"
puts "4. Delete Mousecape/mousecloak/vendor/GBCli/ directory"
puts "5. Build the project (Cmd+B)"
