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

# Create package reference manually
puts "Creating Swift Package reference for ArgumentParser"

# Generate UUIDs for the new objects
package_ref_uuid = SecureRandom.uuid.upcase.gsub('-', '')[0..23]
product_ref_uuid = SecureRandom.uuid.upcase.gsub('-', '')[0..23]

# Read the project file
pbxproj_path = File.join(project_path, 'project.pbxproj')
content = File.read(pbxproj_path)

# Find the root object UUID
root_uuid = content.match(/rootObject = ([A-F0-9]+)/)[1]

# Add XCRemoteSwiftPackageReference section if it doesn't exist
unless content.include?('XCRemoteSwiftPackageReference')
  # Find the end of PBXFileReference section
  file_ref_end = content.index('/* End PBXFileReference section */')

  package_section = <<~PACKAGE

  /* Begin XCRemoteSwiftPackageReference section */
  \t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference "swift-argument-parser" */ = {
  \t\t\tisa = XCRemoteSwiftPackageReference;
  \t\t\trepositoryURL = "https://github.com/apple/swift-argument-parser";
  \t\t\trequirement = {
  \t\t\t\tkind = upToNextMajorVersion;
  \t\t\t\tminimumVersion = 1.2.0;
  \t\t\t};
  \t\t};
  /* End XCRemoteSwiftPackageReference section */
  PACKAGE

  content.insert(file_ref_end + '/* End PBXFileReference section */'.length, package_section)
end

# Add XCSwiftPackageProductDependency section if it doesn't exist
unless content.include?('XCSwiftPackageProductDependency')
  # Find a good place to insert (after XCRemoteSwiftPackageReference)
  insert_pos = content.index('/* End XCRemoteSwiftPackageReference section */')

  product_section = <<~PRODUCT

  /* Begin XCSwiftPackageProductDependency section */
  \t\t#{product_ref_uuid} /* ArgumentParser */ = {
  \t\t\tisa = XCSwiftPackageProductDependency;
  \t\t\tpackage = #{package_ref_uuid} /* XCRemoteSwiftPackageReference "swift-argument-parser" */;
  \t\t\tproductName = ArgumentParser;
  \t\t};
  /* End XCSwiftPackageProductDependency section */
  PRODUCT

  content.insert(insert_pos + '/* End XCRemoteSwiftPackageReference section */'.length, product_section)
end

# Find the mousecloak target UUID
target_uuid = mousecloak_target.uuid

# Add package reference to root object's packageReferences array
root_object_match = content.match(/#{root_uuid}[^=]+=\s*\{[^}]+isa = PBXProject;.*?(?=\n\t\t\};)/m)
if root_object_match
  root_object_text = root_object_match[0]

  unless root_object_text.include?('packageReferences')
    # Add packageReferences array before the closing brace
    package_ref_line = "\t\t\tpackageReferences = (\n\t\t\t\t#{package_ref_uuid} /* XCRemoteSwiftPackageReference \"swift-argument-parser\" */,\n\t\t\t);\n"

    # Find the position to insert (before targets array or at the end)
    insert_pos = content.index(root_object_text) + root_object_text.length
    content.insert(insert_pos, "\n" + package_ref_line)
  end
end

# Add package product dependency to mousecloak target
target_match = content.match(/#{target_uuid}[^=]+=\s*\{[^}]+isa = PBXNativeTarget;.*?(?=\n\t\t\};)/m)
if target_match
  target_text = target_match[0]

  unless target_text.include?('packageProductDependencies')
    # Add packageProductDependencies array
    package_dep_line = "\t\t\tpackageProductDependencies = (\n\t\t\t\t#{product_ref_uuid} /* ArgumentParser */,\n\t\t\t);\n"

    insert_pos = content.index(target_text) + target_text.length
    content.insert(insert_pos, "\n" + package_dep_line)
  end
end

# Write the modified content back
File.write(pbxproj_path, content)

puts "✅ Swift ArgumentParser package added successfully!"
puts ""
puts "Package details:"
puts "  - Repository: https://github.com/apple/swift-argument-parser"
puts "  - Version: >= 1.2.0"
puts "  - Target: mousecloak"
puts ""
puts "Next steps:"
puts "1. Open Mousecape.xcodeproj in Xcode"
puts "2. Xcode will automatically resolve the package dependency"
puts "3. Build the project (Cmd+B)"
