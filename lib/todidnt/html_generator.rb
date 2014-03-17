module Todidnt
  class HTMLGenerator
    COMMON_FILES = %w{style.css, jquery-2.1.0.min.js, chosen.jquery.min.js, chosen.min.css}

    def self.path_to
      File.join(File.dirname(File.expand_path(__FILE__)), '../..')
    end

    def self.common
      COMMON_FILES.each do |file|
        FileUtils.cp("#{path_to}templates/#{file}", "#{file}")
      end
    end

    def self.render(template, context)
      template_name = template.to_s

      content_template = Tilt::ERBTemplate.new("#{path_to}/templates/#{template_name}.erb")
      layout_template = Tilt::ERBTemplate.new("#{path_to}/templates/layout.erb")

      content = content_template.render nil, context
      result = layout_template.render { content }

      File.open("todidnt_#{template_name}.html", 'w') do |file|
        file.write(result)
      end
    end
  end
end
