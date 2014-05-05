require 'tilt'
require 'erb'
require 'fileutils'
require 'json'

module Todidnt
  class HTMLGenerator
    SOURCE_PATH = File.join(
      File.dirname(File.expand_path(__FILE__)),
      '../../templates'
    )
    DESTINATION_PATH = '.todidnt'

    def self.generate_common
      # Create the destination folder unless it already exists.
      FileUtils.mkdir_p(DESTINATION_PATH)

      # Copy over directories (e.g. js, css) to the destination.
      common_dirs = []
      Dir.chdir(SOURCE_PATH) do
        common_dirs = Dir.glob('*').select do |dir|
          File.directory?(dir)
        end
      end

      common_dirs.each do |dir|
        FileUtils.cp_r(
          source_path(dir),
          destination_path,
          :remove_destination => true
        )
      end
    end

    def self.generate(template, context={})
      generate_common

      content_template = from_template(template)
      layout_template = from_template(:layout)

      inner_content = content_template.render nil, context
      result = layout_template.render { inner_content }

      file_name = destination_path("todidnt_#{template}.html")
      File.open(file_name, 'w') do |file|
        file.write(result)
      end

      File.absolute_path(file_name)
    end

    def self.source_path(path=nil)
      path ? "#{SOURCE_PATH}/#{path}" : SOURCE_PATH
    end

    def self.destination_path(path=nil)
      path ? "#{DESTINATION_PATH}/#{path}" : DESTINATION_PATH
    end

    def self.from_template(template)
      Tilt::ERBTemplate.new(source_path("#{template}.erb"))
    end
  end
end
