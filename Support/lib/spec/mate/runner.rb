require 'eunit_formatter'

RUN_INCLUDE_PATHS = "-pa ./ebin -pa ./ebin/eunit -pa ./ebin/mochiweb -pa ./ebin/mysql -pa ./include -pa ./src"
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

      def run(stdout, options)
        erl = `which erl`
        erl = "/opt/local/bin/erl"
        erlc = "/opt/local/bin/erlc"

        formatter = EunitFormatter.new(stdout)
        counter = 1
        Dir.chdir(project_directory) do
          #stdout << options[:files].join('::::')
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
              test_output = `#{erl} +K true -pz ./test -pz ./ebin/ -pa ./ebin/eunit -pa ./ebin/mysql -pa ./ebin/mochiweb -s mnesia start -sname master2 -noshell -run #{erlang_module} test -run init stop`
              formatter.example_started("#{erlang_module}")
              if /\*failed\*/ =~ test_output or /error/ =~ test_output or /terminating/ =~ test_output
                formatter.example_failed("#{erlang_module}", counter, "#{test_output}")
                counter += 1
              else
                test_output[/1>\s*(.*)\n/]
                formatter.example_passed("#{erlang_module}")
              end
            end
          end
        end
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
