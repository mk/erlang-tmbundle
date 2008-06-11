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

      def run(stdout, options)
        erl = `which erl`
        erl = "/opt/local/bin/erl"
        #argv = options[:files].dup
        #argv << '--format'
        #argv << 'textmate'
        #if options[:line]
        #  argv << '--line'
        #  argv << options[:line]
        #end
        #argv += ENV['TM_RSPEC_OPTS'].split(" ") if ENV['TM_RSPEC_OPTS']
        #Dir.chdir(project_directory) do
        #  ::Spec::Runner::CommandLine.run(::Spec::Runner::OptionParser.parse(argv, STDERR, stdout))
        #end
        
        Dir.chdir(project_directory) do
          options[:files].each do |file|
            erlang_module = file.match(/test\/(.*)_test.erl/)[1]
            test_output = `#{erl} -pa ebin ebin/eunit -run #{erlang_module} test -run init stop`
            if /\*failed\*/ =~ test_output
              puts "Failures in #{erlang_module}:\n#{test_output}"
            else
              test_output[/1>\s*(.*)\n/]
              puts "#{erlang_module}: #{$1}"
            end
          end
        end
        #Dir.chdir(project_directory) do
        #  ::Spec::Runner::CommandLine.run()
        #end
      end

      protected
      def single_file
        File.expand_path(ENV['TM_FILEPATH'])
      end

      def project_directory
        File.expand_path(ENV['TM_PROJECT_DIRECTORY'])
      end
    end
  end
end
