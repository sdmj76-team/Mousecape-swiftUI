#!/usr/bin/env ruby

require 'securerandom'

# Read the project file
pbxproj_path = 'Mousecape/Mousecape.xcodeproj/project.pbxproj'
content = File.read(pbxproj_path)

# Find the ArgumentParser product dependency UUID
product_dep_uuid = content.match(/([A-F0-9]+) \/\* ArgumentParser \*\/ = \{[^}]+isa = XCSwiftPackageProductDependency/)[1]

puts "Found ArgumentParser product dependency: #{product_dep_uuid}"

# Generate a new UUID for the build file
build_file_uuid = SecureRandom.uuid.upcase.gsub('-', '')[0..23]

puts "Generated build file UUID: #{build_file_uuid}"

# Add the build file entry in PBXBuildFile section
build_file_entry = "\t\t#{build_file_uuid} /* ArgumentParser in Frameworks */ = {isa = PBXBuildFile; productRef = #{product_dep_uuid} /* ArgumentParser */; };\n"

# Find the end of PBXBuildFile section
build_file_section_end = content.index('/* End PBXBuildFile section */')
content.insert(build_file_section_end, build_file_entry)

# Add the build file to mousecloak's Frameworks build phase
# Find FAC69FAA189D608900BC829D (mousecloak Frameworks phase)
frameworks_phase_match = content.match(/(FAC69FAA189D608900BC829D \/\* Frameworks \*\/ = \{[^}]+files = \([^)]+)/m)

if frameworks_phase_match
  insert_pos = content.index(frameworks_phase_match[0]) + frameworks_phase_match[0].length
  framework_entry = "\n\t\t\t\t#{build_file_uuid} /* ArgumentParser in Frameworks */,"
  content.insert(insert_pos, framework_entry)
  puts "Added ArgumentParser to mousecloak Frameworks build phase"
else
  puts "ERROR: Could not find mousecloak Frameworks build phase"
  exit 1
end

# Write the modified content back
File.write(pbxproj_path, content)

puts "✅ ArgumentParser successfully linked to mousecloak target!"
puts ""
puts "Next step: Build the project"
puts "  xcodebuild -project Mousecape/Mousecape.xcodeproj -target mousecloak build"
