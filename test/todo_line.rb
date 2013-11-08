require_relative 'lib'

class TestTodoLine < Test
  before do
    Todidnt::GitCommand.any_instance.stubs(:run!)
  end

  describe '.all' do
    describe 'unit' do
      it 'constructs the correct `git grep` command' do
        grep = mock()
        grep.stubs(:output_lines => [])

        Todidnt::GitCommand.expects(:new).with(:grep, [['-n'], ['-e', 'hello']]).returns(grep)
        Todidnt::TodoLine.all(['hello'])

        Todidnt::GitCommand.expects(:new).with(:grep, [['-n'], ['-e', 'hello'], ['-e', 'goodbye']]).returns(grep)
        Todidnt::TodoLine.all(['hello', 'goodbye'])
      end

      it 'creates a TodoLine object for each result line properly' do
        Todidnt::GitCommand.any_instance.expects(:output_lines).returns(
          [
            'filename.rb:12:     content',
            'other_filename.rb:643:    TODO'
          ]
        )

        Todidnt::TodoLine.expects(:new).with('filename.rb', 12, 'content')
        Todidnt::TodoLine.expects(:new).with('other_filename.rb', 643, 'TODO')

        Todidnt::TodoLine.all(['anything'])
      end
    end

    describe 'functional' do
      it 'returns a list of TodoLine objects as matches' do
        Todidnt::GitCommand.any_instance.expects(:output_lines).returns(
          [
            'filename.rb:12:     content',
            'other_filename.rb:643:    TODO'
          ]
        )

        todos = Todidnt::TodoLine.all(['anything'])
        assert_equal 2, todos.count

        assert_equal 'filename.rb', todos.first.filename
        assert_equal 12, todos.first.line_number
        assert_equal 'content', todos.first.content

        assert_equal 'other_filename.rb', todos.last.filename
        assert_equal 643, todos.last.line_number
        assert_equal 'TODO', todos.last.content
      end

      it 'ignores lines matching IGNORE list' do
        Todidnt::GitCommand.any_instance.expects(:output_lines).returns(
          [
            'filename.rb:12:     content',
            'thirdparty/other_filename.rb:643:    TODO'
          ]
        )

        todos = Todidnt::TodoLine.all(['anything'])
        assert_equal 1, todos.count

        assert_equal 'filename.rb', todos.first.filename
        assert_equal 12, todos.first.line_number
        assert_equal 'content', todos.first.content
      end
    end
  end

  describe '#populate_blame' do
    it 'constructs the correct `git blame` command' do
      blame = mock()
      blame.expects(:output_lines).returns([])
      Todidnt::GitCommand.expects(:new).with(:blame,
        [
          ['--line-porcelain'],
          ['-L', '50,50'],
          ['filename.rb']
        ]
      ).returns(blame)

      todo_line = Todidnt::TodoLine.new('filename.rb', 50, 'commit message')
      todo_line.populate_blame
    end

    it 'sets author, timestamp properties on the TodoLine object' do
      blame = mock()
      blame.expects(:output_lines).returns(
        %w{
          39efeb14a9 1 1
          author Amber Feng
          author-time 1383882788
          author-mail <amber.feng@gmail.com>,
          summary Commit message,
        }
      )
      Todidnt::GitCommand.expects(:new).returns(blame)

      todo_line = Todidnt::TodoLine.new('filename.rb', 50, 'commit message')
      todo_line.populate_blame
    end
  end
end
