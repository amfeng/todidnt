module Todidnt
  class HTMLGenerator
    COMMON_FILES = %w{style.css jquery-2.1.0.min.js chosen.jquery.min.js chosen.min.css}
    PATH_TO = File.join(File.dirname(File.expand_path(__FILE__)), '../..')

    def self.common
      COMMON_FILES.each do |file|
        FileUtils.cp("#{path_to}templates/#{file}", "#{file}")
      end
    end

    def self.generate(template, context)
      content_template = from_template(template)
      layout_template = from_template(:layout)

      inner_content = content_template.render nil, context
      result = layout_template.render { inner_content }

      file_name = generated_file_name(template)
      File.open(file_name, 'w') do |file|
        file.write(result)
      end

      File.absolute_path(file_name)
    end

    def self.path_to(path)
      "#{PATH_TO}/#{path}"
    end

    def self.from_template(template)
      Tilt::ERBTemplate.new(path_to("templates/#{template}.erb"))
    end

    def self.generated_file_name(template)
      "todidnt_#{template}.html"
    end

  end
end
