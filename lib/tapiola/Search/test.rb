require 'citrus'
require 'tempfile'


g = Citrus.eval(<<HERE)
grammar Predicate

#rule allCriteria
#    logCriteria | simpleBracketCriteria |   
#      (logCriteria wSpace logOp wSpace simpleBracketCriteria) |   
#        (simpleBracketCriteria wSpace logOp wSpace logCriteria)
#end

rule searchExp
    relExp  |   
    searchExp  wChar  logOp  wChar  searchExp  | 
     openBracket  wChar*  searchExp  wChar*  closeBracket
end


#rule simpleBracketCriteria
#    openBracket wSpace* logCriteria wSpace* closeBracket
#end

rule openBracket
    '('
end

rule closeBracket
    ')'
end

#rule logCriteria
#    criterion (wSpace logOp wSpace criterion)*
#end

rule logOp
    'and' | 'or'
end

rule relExp
    property wSpace relOp wSpace quotedVal
end

rule relOp
    '=' | '!=' | '<' | '<=' | '>=' | '>'
end


rule property
    'name' | 'title'
end

rule wSpace
  /\s+/
end

rule quotedVal
/"((\\\\{2})*|(.*?[^\\\\](\\\\{2})*))"/
end



end
HERE



m = Predicate.parse '(name = "james" or name = "fr\\"ed" or title = "mr")'
m = Predicate.parse 'name = "james" or name = "fr\\"ed" or title = "mr"'
m = Predicate.parse '(name = "james" and name = "fred")'
m = Predicate.parse 'name = "banana"'


m = Predicate.parse 'name = "james" and name = "fred" or name = "banana"' 


m = Predicate.parse '(name = "james" and name = "fred") or name = "banana"' 

m = Predicate.parse 'name = "james" and name = "fred" or (name = "banana")'
#m.dump