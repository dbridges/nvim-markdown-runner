if exists("g:loaded_markdown_runner")
  finish
endif

command! MarkdownRunner lua require("markdown_runner").echo()
command! MarkdownRunnerInsert lua require("markdown_runner").insert()

let g:loaded_markdown_runner = 1
