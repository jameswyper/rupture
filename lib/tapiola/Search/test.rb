require 'citrus'
require 'tempfile'
require 'minitest/autorun'


$g = Citrus.eval(<<HERE)
grammar Search


#rule testy
 #  atomic wChar+ logOp wChar+ atomic
#end

rule searchCrit
    searchExp | '*'
end

rule searchExp
    compound | simpleOrBracketed
end

rule compound
    simpleOrBracketed wChar+ logOp wChar+ searchExp
end

rule simpleOrBracketed
    relExp |  bracketed
end

rule bracketed
    '(' wChar*  searchExp  wChar*  ')'
end

rule logOp
    'and' | 'or'
end

rule relExp
    compareExp | existExp
end

rule compareExp
    property wChar+ binOp wChar+ quotedVal 
end

rule existExp
    property wChar+ 'exists' wChar+ boolVal
end

rule boolVal
    'true' | 'false'
end

rule binOp
    relOp | stringOp
end

rule stringOp
    'contains' | 'doesNotContain' | 'derivedFrom'
end

rule relOp
    '=' | '!=' | '<' | '<=' | '>=' | '>'
end

rule property
    'name' | 'title'
end

rule wChar
  /\s/
end

rule quotedVal
  /"(?:[^"\\\\]|\\\\\\\\|\\\\")*"/
end

end
HERE



class TestParsing < MiniTest::Test
    def setup
        @tries = {'name = "fred"' => true,
            'name = "james" or name = "fred"' => true,
            'name = "james" or name = "fr\\"ed" or title = "mr"' => true,
            'name = "banana"' => true,
            'name = "james" and name = "fred" or name = "banana"' => true,
            '(name = "james" and name = "fred") or name = "banana"'=> true,
             'name = "james" and name = "fred" or (name = "banana")' => true,
            '(name = "james") or (title = "fred" and (title = "banana" or n5ame = "apple"))'=> false}
    end

    def test_something
        @tries.each do |t,w|

            if (w)
                begin
                    m = Search.parse t
                rescue Citrus::ParseError
                end
                refute_nil m,"parsing failed unexpectedly for #{t}"
            else
                assert_raises(Citrus::ParseError,"parsing should not have worked for #{t}") {m =Search.parse t}
                assert_nil m
            end
        
        end
    end

    def teardown
    end
end




