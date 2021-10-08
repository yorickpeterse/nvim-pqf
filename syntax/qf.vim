if exists('b:current_syntax')
  finish
end

syntax clear

let b:current_syntax = 'qf'

lua require('pqf').syntax()
