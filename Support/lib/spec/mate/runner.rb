require 'eunit_formatter'

RUN_INCLUDE_PATHS = "-pa ./ebin -pa ./ebin/eunit -pa ./ebin/mochiweb -pa ./ebin/edbi -pa ./include -pa ./src"
ERLC_TEST_FLAGS = "#{RUN_INCLUDE_PATHS} -I ./include -pa ./ebin/eunit -I . -I ./test -I ./include/eunit -DTEST"
ERLC_FLAGS = "+debug_info -W2 -I ./include -o ./ebin -pa ./ebin -pa ./ebin/mochiweb"

module Spec
  module Mate
    class Runner
      def run_files(stdout, options={})
        files = ENV['TM_SELECTED_FILES'].split(" ").map do |path|
          File.expand_path(path[1..-2])
        end
        options.merge!({:files => files})
        run(stdout, options)
      end

      def run_file(stdout, options={})
        options.merge!({:files => [single_file]})
        run(stdout, options)
      end

      def run_focussed(stdout, options={})
        options.merge!({:files => [single_file], :line => ENV['TM_LINE_NUMBER']})
        run(stdout, options)
      end
      
      def run_edoc(stdout, options={})
        erl = "/opt/local/bin/erl"
        doc_dir = "#{ENV['TM_PROJECT_DIRECTORY']}/doc/edoc"
        `mkdir -p "#{doc_dir}"`
        Dir.chdir(doc_dir) do
          result = `#{erl} -noshell -s init stop -run edoc files "#{ENV['TM_FILEPATH']}"`
          if result == ""
            doc_file = doc_dir + "/" + File.basename(ENV['TM_FILEPATH'], ".erl") + ".html"
            f = File.new(doc_file)
            puts f.readlines
          else
            puts "<h1>Error</h1>"
            result.each_line do |line|
              puts "#{line}<br/>"
            end            
          end
        end
      end

      def run(stdout, options)
        @start_time = Time.now
        erl = `which erl`
        erl = "/opt/local/bin/erl"
        erlc = "/opt/local/bin/erlc"
        
        formatter = EunitFormatter.new(stdout)
        counter = 0
        failed_counter = 0
        skipped_counter = 0
        Dir.chdir(project_directory) do
          options[:files].each { |dir| 
            options[:files] = options[:files] + files_in(dir) if File.directory?(dir)
          }
          options[:files] = options[:files].delete_if{ |file| File.directory?(file) }
          formatter.start(options[:files].size)
          options[:files].each do |file|
            normal_file_match = file.match(/src\/(.*).erl/)
            erlang_module = normal_file_match.nil? ? file.match(/test\/(.*)_test.erl/)[1] : normal_file_match[1]
            compilation_output = `#{erlc} #{ERLC_TEST_FLAGS} -o ./ebin ./src/#{erlang_module}.erl`
            formatter.add_example_group("Module #{erlang_module}")
            abort_run = false
            if /error/ =~ compilation_output or /Error/ =~ compilation_output or /unbound/ =~ compilation_output or /undefined/ =~ compilation_output or /can't find/ =~ compilation_output
              formatter.example_started("compilation")
              formatter.example_failed("compilation", counter, "#{compilation_output}")
              counter += 1
              abort_run = true
            elsif /Warning/ =~ compilation_output
              formatter.example_started("compilation")
              formatter.example_pending("compilation", counter, "#{compilation_output}")
              counter += 1
            end
            unless abort_run
              test_output = `#{erl} +K true -pz ./test -pz ./ebin/ -pa ./ebin/eunit -pa ./ebin/edbi -pa ./ebin/mochiweb -s mnesia start -sname master2 -noshell -s util test_module #{erlang_module} -run init stop`
              started_failure_output = false
              failure_output = []
              test_name = ''
              test_output.split("\n").each do |line|
                if /done in / =~ line or /===========/ =~ line or /Succeeded:/ =~ line
                  # we ignore those lines
                  formatter.example_failed(test_name, counter, failure_output.join("\n")) if started_failure_output
                  started_failure_output = false
                  failure_output = []
                elsif /tests were cancelled/ =~ line
                  formatter.example_failed("TESTS CANCELED", counter, line)
                elsif line == "*failed*"
                  started_failure_output = true
                elsif !(match = line.match(/\:\s*(\w*)_test.*\.\.\./)).nil?
                  counter += 1
                  if started_failure_output
                    formatter.example_failed(test_name, counter, failure_output.join("\n"))
                    failed_counter += 1
                    failure_output = []
                  end
                  test_name = match[1].gsub('_', ' ')
                  formatter.example_started(test_name)
                  if /_test.*\.\.\..*ok$/ =~ line
                    formatter.example_passed(test_name)
                    started_failure_output = false
                  elsif /_test.*\.\.\..*\*failed\*$/ =~ line
                    started_failure_output = true
                  elsif /_test.*\.\.\..*\*skipped\*$/ =~ line
                    test_name += " (SKIPPED)"
                    skipped_counter += 1
                    started_failure_output = true
                  end
                elsif /module '.*'$/ =~ line
                  #formatter.example_started("#{erlang_module}")
                elsif /\[\d+(\.\d+)? s\] ok$/ =~ line 
                  # if test traces messages, the ok message comes at the end and
                  # looks like that: [3.016 s] ok
                  formatter.example_passed(test_name)
                  started_failure_output = false
                else
                  failure_output << line
                end
              end
              @end_time = Time.now
              # print last failure
              if started_failure_output
                formatter.example_failed(test_name, counter, failure_output.join("\n")) 
                failed_counter += 1
              end
              formatter.dump_summary(duration, counter, failed_counter, skipped_counter)
            end
          end
        end
      end

      protected
      def duration
        return @end_time - @start_time unless (@end_time.nil? or @start_time.nil?)
        return "0.0"
      end
      
      def single_file
        File.expand_path(ENV['TM_FILEPATH'])
      end

      def project_directory
        File.expand_path(ENV['TM_PROJECT_DIRECTORY'])
      end
      
      def files_in(directory)
        Dir.entries(directory).reject{ |name| name == "." and name == ".." }.collect{ |name| "#{directory}/#{name}"}
      end
    end
  end
end
