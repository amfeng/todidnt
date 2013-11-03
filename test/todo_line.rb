require_relative 'lib'

class TestTodoLine < Test
  before do
    GitCommand.any_instance.stubs(:run!)
  end

  describe '.all' do
    describe 'unit' do
      it 'constructs the correct `git grep` command' do
        grep = mock()
        grep.stubs(:output_lines => [])

        GitCommand.expects(:new).with(:grep, [['-n'], ['-e', 'hello']]).returns(grep)
        TodoLine.all(['hello'])

        GitCommand.expects(:new).with(:grep, [['-n'], ['-e', 'hello'], ['-e', 'goodbye']]).returns(grep)
        TodoLine.all(['hello', 'goodbye'])
      end

      it 'creates a TodoLine object for each result line properly' do
        GitCommand.any_instance.expects(:output_lines).returns(
          [
            'filename.rb:12:     content',
            'other_filename.rb:643:    TODO'
          ]
        )

        TodoLine.expects(:new).with('filename.rb', 12, 'content')
        TodoLine.expects(:new).with('other_filename.rb', 643, 'TODO')

        TodoLine.all(['anything'])
      end

      it 'truncates long content' do
        # TODO
        skip
      end
    end

    describe 'functional' do
      it 'returns a list of TodoLine objects as matches' do
        GitCommand.any_instance.expects(:output_lines).returns(
          [
            'filename.rb:12:     content',
            'other_filename.rb:643:    TODO'
          ]
        )

        todos = TodoLine.all(['anything'])
        assert_equal 2, todos.count

        assert_equal 'filename.rb', todos.first.filename
        assert_equal 12, todos.first.line_number
        assert_equal 'content', todos.first.content

        assert_equal 'other_filename.rb', todos.last.filename
        assert_equal 643, todos.last.line_number
        assert_equal 'TODO', todos.last.content
      end

      it 'ignores lines matching IGNORE list' do
        GitCommand.any_instance.expects(:output_lines).returns(
          [
            'filename.rb:12:     content',
            'thirdparty/other_filename.rb:643:    TODO'
          ]
        )

        todos = TodoLine.all(['anything'])
        assert_equal 1, todos.count

        assert_equal 'filename.rb', todos.first.filename
        assert_equal 12, todos.first.line_number
        assert_equal 'content', todos.first.content
      end
    end
  end

  describe '#populate_blame' do
    it 'constructs the correct `git blame` command' do
      # TODO
      skip
    end

    it 'sets author, timestamp properties on the TodoLine object' do
      # TODO
      skip
    end
  end
end
