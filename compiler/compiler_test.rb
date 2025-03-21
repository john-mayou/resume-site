require 'minitest/autorun'
require 'shellwords'
require 'open3'

require_relative 'compiler.rb'

UPDATE = ENV['UPDATE'] == 'true' # example

class Minitest::Test
  make_my_diffs_pretty!
end

def unformat_html(html)
  html.gsub!(/^\s+|\s+$/, '')
  html.gsub!("\n", '')
  html
end

module Compiler
  class TestCompile < Minitest::Test
    [
      {md: '', expected: ''},
    ].each_with_index do |tc, i|
      define_method("test_compile_empty_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: 'text', expected: '<p>text</p>'},
      {md: 'text #', expected: '<p>text #</p>'},
      {md: 'text text', expected: '<p>text text</p>'},
      {md: "line 1\nline 2", expected: '<p>line 1 line 2</p>'},
      {md: "line 1\n\nline 2", expected: '<p>line 1</p><p>line 2</p>'},
      {md: "line 1\n\n\nline 2", expected: '<p>line 1</p><p>line 2</p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_paragraph_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '# text', expected: '<h1>text</h1><hr>'},
      {md: '## text', expected: '<h2>text</h2><hr>'},
      {md: '### text', expected: '<h3>text</h3><hr>'},
      {md: '#### text', expected: '<h4>text</h4><hr>'},
      {md: '##### text', expected: '<h5>text</h5><hr>'},
      {md: '###### text', expected: '<h6>text</h6><hr>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_header_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: "text\n====", expected: '<h1>text</h1><hr>'},
      {md: "text\n----", expected: '<h2>text</h2><hr>'},
      {md: "text\n====    ", expected: '<h1>text</h1><hr>'},
      {md: "text\n----    ", expected: '<h2>text</h2><hr>'},
      {md: "lbefore\ntext\n====", expected: '<p>lbefore</p><h1>text</h1><hr>'},
      {md: "lbefore\ntext\n----", expected: '<p>lbefore</p><h2>text</h2><hr>'},
      {md: "\ntext\n====\nlafter", expected: '<h1>text</h1><hr><p>lafter</p>'},
      {md: "\ntext\n----\nlafter", expected: '<h2>text</h2><hr><p>lafter</p>'},
      {md: "lbefore\ntext\n====\nlafter", expected: '<p>lbefore</p><h1>text</h1><hr><p>lafter</p>'},
      {md: "lbefore\ntext\n----\nlafter", expected: '<p>lbefore</p><h2>text</h2><hr><p>lafter</p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_header_alt_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '**text**', expected: '<p><b>text</b></p>'},
      {md: '__text__', expected: '<p><b>text</b></p>'},
      {md: '**text****text**', expected: '<p><b>text</b><b>text</b></p>'},
      {md: '__text____text__', expected: '<p><b>text</b><b>text</b></p>'},
      {md: '**text*', expected: '<p>*<i>text</i></p>'},
      {md: '__text_', expected: '<p>_<i>text</i></p>'},
      {md: '*text**', expected: '<p><i>text</i>*</p>'},
      {md: '_text__', expected: '<p><i>text</i>_</p>'},
      {md: 'before **text**', expected: '<p>before <b>text</b></p>'},
      {md: '**text** after', expected: '<p><b>text</b> after</p>'},
      {md: 'before **text** after', expected: '<p>before <b>text</b> after</p>'},
      {md: '(**text**)', expected: '<p>(<b>text</b>)</p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_emphasis_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '*text*', expected: '<p><i>text</i></p>'},
      {md: '_text_', expected: '<p><i>text</i></p>'},
      {md: '*text**text*', expected: '<p><i>text</i><i>text</i></p>'},
      {md: '_text__text_', expected: '<p><i>text</i><i>text</i></p>'},
      {md: '*text', expected: '<p>*text</p>'},
      {md: '_text', expected: '<p>_text</p>'},
      {md: 'text*', expected: '<p>text*</p>'},
      {md: 'text_', expected: '<p>text_</p>'},
      {md: 'before *text*', expected: '<p>before <i>text</i></p>'},
      {md: '*text* after', expected: '<p><i>text</i> after</p>'},
      {md: 'before *text* after', expected: '<p>before <i>text</i> after</p>'},
      {md: '(*text*)', expected: '<p>(<i>text</i>)</p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_italic_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '***text***', expected: '<p><i><b>text</b></i></p>'},
      {md: '___text___', expected: '<p><i><b>text</b></i></p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_emphasis_italic_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '![alt](src)', expected: '<img alt="alt" src="src"/>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_image_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '[text](href)', expected: '<p><a href="href">text</a></p>'},
      {md: 'before [text](href)', expected: '<p>before <a href="href">text</a></p>'},
      {md: '[text](href) after', expected: '<p><a href="href">text</a> after</p>'},
      {md: 'before [text](href) after', expected: '<p>before <a href="href">text</a> after</p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_link_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '**', expected: '<p>**</p>'},
      {md: '--', expected: '<p>--</p>'},
      {md: '***', expected: '<hr>'},
      {md: '---', expected: '<hr>'},
      {md: '***   ', expected: '<hr>'},
      {md: '---   ', expected: '<hr>'},
      {md: '*******', expected: '<hr>'},
      {md: '-------', expected: '<hr>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_horizontal_rule_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {
        md: <<~MD,
          * 1
          - 2
          * 3
        MD
        expected: unformat_html(String.new(<<~HTML)),
          <ul>
            <li>1</li>
            <li>2</li>
            <li>3</li>
          </ul>
        HTML
      },
      {
        md: <<~MD,
          * 1
          - 2
              * 2.1
                  - 2.1.1
              * 2.2
          - 3
        MD
        expected: unformat_html(String.new(<<~HTML)),
          <ul>
            <li>1</li>
            <li>
              2
              <ul>
                <li>
                  2.1
                  <ul>
                    <li>2.1.1</li>
                  </ul>
                </li>
                <li>2.2</li>
              </ul>
            </li>
            <li>3</li>
          </ul>
        HTML
      }
    ].each_with_index do |tc, i|
      define_method("test_compile_unordered_list_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {
        md: <<~MD,
          1. 1
          2. 2
          3. 3
        MD
        expected: unformat_html(String.new(<<~HTML)),
          <ol>
            <li>1</li>
            <li>2</li>
            <li>3</li>
          </ol>
        HTML
      },
      {
        md: <<~MD,
          1. 1
          2. 2
              1. 2.1
                  1. 2.1.1
              2. 2.2
          3. 3
        MD
        expected: unformat_html(String.new(<<~HTML)),
          <ol>
            <li>1</li>
            <li>
              2
              <ol>
                <li>
                  2.1
                  <ol>
                    <li>2.1.1</li>
                  </ol>
                </li>
                <li>2.2</li>
              </ol>
            </li>
            <li>3</li>
          </ol>
        HTML
      }
    ].each_with_index do |tc, i|
      define_method("test_compile_ordered_list_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {
        md: <<~MD,
          ```
          code line 1
          code line 2
          ```
        MD
        expected: String.new("<pre><code class=\"\">code line 1\ncode line 2\n</code></pre>")
      },
      {
        md: <<~MD,
          ```ruby
          code with lang
          ```
        MD
        expected: String.new("<pre><code class=\"ruby\">code with lang\n</code></pre>")
      }
    ].each_with_index do |tc, i|
      define_method("test_compile_code_block_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {md: '`syntax`', expected: '<p><code class="">syntax</code></p>'},
      {md: 'before`syntax`', expected: '<p>before<code class="">syntax</code></p>'},
      {md: 'beforebefore before`syntax`', expected: '<p>beforebefore before<code class="">syntax</code></p>'},
      {md: '`syntax`after', expected: '<p><code class="after">syntax</code></p>'},
      {md: '`syntax`after afterafter', expected: '<p><code class="after">syntax</code> afterafter</p>'},
      {md: '`syntax``syntax 2`', expected: '<p><code class="">syntax``syntax 2</code></p>'},
    ].each_with_index do |tc, i|
      define_method("test_compile_code_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end

    [
      {
        md: <<~MD,
          > line 1
          > line 2
        MD
        expected: unformat_html(String.new(<<~HTML))
          <blockquote>
            <p>line 1 line 2</p>
          </blockquote>
        HTML
      },
      {
        md: <<~MD,
          > line 1
          >
          > line 2
        MD
        expected: unformat_html(String.new(<<~HTML))
          <blockquote>
            <p>line 1</p>
            <p>line 2</p>
          </blockquote>
        HTML
      },
      {
        md: <<~MD,
          > line 1
          >
          > > subline 1.1
          > >
          > > > subsubline 1.1.1
          > >
          > > subline 1.2
          >
          > line 2
        MD
        expected: unformat_html(String.new(<<~HTML))
          <blockquote>
            <p>line 1</p>
            <blockquote>
              <p>subline 1.1</p>
              <blockquote>
                <p>subsubline 1.1.1</p>
              </blockquote>
              <p>subline 1.2</p>
            </blockquote>
            <p>line 2</p>
          </blockquote>
        HTML
      }
    ].each_with_index do |tc, i|
      define_method("test_compile_block_quote_#{i}") do
        assert_equal tc[:expected], Compiler.compile(tc[:md])
      end
    end
  end

  class TestLexer < Minitest::Test
    def tokenize(md)
      Lexer.new(md).tokenize
    end

    def test_tokenize_blank
      assert_equal [], tokenize('')
    end

    def test_tokenize_paragraph
      assert_equal [
        Lexer::Token.new(:text, {text: 'text', bold: false, italic: false}),
        Lexer::Token.new(:newl),
      ], tokenize('text')
    end

    def test_tokenize_list
      assert_equal [
        Lexer::Token.new(:listi, {indent: 0, ordered: true, digit: 1}),
        Lexer::Token.new(:text, {text: '1', bold: false, italic: false}),
        Lexer::Token.new(:newl),
        Lexer::Token.new(:listi, {indent: 1, ordered: false}),
        Lexer::Token.new(:text, {text: '1.1', bold: false, italic: false}),
        Lexer::Token.new(:newl),
      ], tokenize(<<~MD)
        1. 1
            - 1.1
      MD
    end

    def test_tokenize_code_block
      assert_equal [
        Lexer::Token.new(:codeblock, {lang: 'ruby', code: "code\n"}),
        Lexer::Token.new(:newl),
      ], tokenize("```ruby\ncode\n```")
    end

    def test_tokenize_code
      assert_equal [
        Lexer::Token.new(:code, {lang: 'ruby', code: 'code'}),
        Lexer::Token.new(:newl),
      ], tokenize('`code`ruby')
    end
  end

  class TestParser < Minitest::Test
    def parse(tks)
      Parser.new(tks).parse
    end

    def ast_root(*children)
      Parser::NodeRoot.new(children:)
    end

    def test_parse_blank
      assert_equal ast_root, parse([])
    end

    def test_parse_paragraph
      assert_equal ast_root(Parser::NodePara.new(children: [Parser::NodeText.new(text: 'text')])),
        parse([
          Lexer::Token.new(:text, {text: 'text', bold: false, italic: false}),
          Lexer::Token.new(:newl),
        ])
    end

    def test_parse_list
      assert_equal ast_root(Parser::NodeList.new(ordered: true, children: [
        Parser::NodeListItem.new(children: [
          Parser::NodeText.new(text: '1'),
          Parser::NodeList.new(ordered: false, children: [
            Parser::NodeListItem.new(children: [Parser::NodeText.new(text: '1.1')])
          ])
        ])
      ])),
        parse([
          Lexer::Token.new(:listi, {indent: 0, ordered: true, digit: 1}),
          Lexer::Token.new(:text, {text: '1', bold: false, italic: false}),
          Lexer::Token.new(:newl),
          Lexer::Token.new(:listi, {indent: 1, ordered: false}),
          Lexer::Token.new(:text, {text: '1.1', bold: false, italic: false}),
          Lexer::Token.new(:newl),
        ])
    end

    def test_parse_block_quote
      assert_equal ast_root(Parser::NodeQuote.new(children: [
        Parser::NodeQuoteItem.new(children: [
          Parser::NodeText.new(text: 'line 1'),
          Parser::NodeText.new(text: ' '),
          Parser::NodeText.new(text: 'line 2'),
        ])
      ])),
        parse([
          Lexer::Token.new(:blockquote, {indent: 1}),
          Lexer::Token.new(:text, {text: 'line 1', bold: false, italic: false}),
          Lexer::Token.new(:newl),
          Lexer::Token.new(:blockquote, {indent: 1}),
          Lexer::Token.new(:text, {text: 'line 2', bold: false, italic: false}),
          Lexer::Token.new(:newl),
        ])
    end

    def test_parse_block_quote_2
      assert_equal ast_root(Parser::NodeQuote.new(children: [
        Parser::NodeQuoteItem.new(children: [Parser::NodeText.new(text: 'line 1')]),
        Parser::NodeQuoteItem.new(children: [Parser::NodeText.new(text: 'line 2')])
      ])),
        parse([
          Lexer::Token.new(:blockquote, {indent: 1}),
          Lexer::Token.new(:text, {text: 'line 1', bold: false, italic: false}),
          Lexer::Token.new(:newl),
          Lexer::Token.new(:blockquote, {indent: 1}),
          Lexer::Token.new(:newl),
          Lexer::Token.new(:blockquote, {indent: 1}),
          Lexer::Token.new(:text, {text: 'line 2', bold: false, italic: false}),
          Lexer::Token.new(:newl),
        ])
    end
  end

  class TestCodeGen < Minitest::Test
    def gen(ast)
      CodeGen.new(ast).gen
    end

    def ast_root(*children)
      Parser::NodeRoot.new(children:)
    end

    def test_gen_blank
      assert_equal '', gen(ast_root)
    end

    def test_gen_paragraph
      assert_equal '<p>text</p>', gen(ast_root(Parser::NodePara.new(children: [Parser::NodeText.new(text: 'text')])))
    end

    def test_gen_list
      assert_equal unformat_html(String.new(<<~HTML)),
          <ol>
            <li>
              1
              <ul>
                <li>1.1</li>
              </ul>
            </li>
          </ol>
        HTML
        gen(ast_root(Parser::NodeList.new(ordered: true, children: [
          Parser::NodeListItem.new(children: [
            Parser::NodeText.new(text: '1'),
            Parser::NodeList.new(ordered: false, children: [
              Parser::NodeListItem.new(children: [Parser::NodeText.new(text: '1.1')])
            ])
          ])
        ])))
    end
  end

  class TestExample < Minitest::Test
    def test_example
      html = Compiler.compile(File.read('testdata/example.txt'))
      html, err, status = Open3.capture3("echo '#{html}' | prettier --parser html")
      if !status.success?
        raise SystemCallError, err
      end

      if UPDATE
        File.write('testdata/example.html', html)
      end

      assert_equal File.read('testdata/example.html'), html
    end
  end
end