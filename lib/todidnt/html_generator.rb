require 'tilt'
require 'erb'
require 'fileutils'

module Todidnt
  class HTMLGenerator
    SOURCE_PATH = File.join(File.dirname(File.expand_path(__FILE__)), '../../templates')
    DESTINATION_PATH = '.todidnt'

    def self.generate_common
      Dir.mkdir(DESTINATION_PATH) unless Dir.exists?(DESTINATION_PATH)

      %w{js css}.each do |dir|
        Dir.foreach(dir) do |file|
          FileUtils.cp(
            source_path(file),
            destination_path(file)
          )
        end
      end
    end

    def self.generate(template, context)
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

    def self.source_path(path)
      "#{SOURCE_PATH}/#{path}"
    end

    def self.destination_path(path)
      "#{DESTINATION_PATH}/#{path}"
    end

    def self.from_template(template)
      Tilt::ERBTemplate.new(source_path("#{template}.erb"))
    end
  end
end
