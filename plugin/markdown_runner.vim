if exists("g:loaded_markdown_runner")
  finish
endif

command! MarkdownRunner lua require("markdown_runner").echo()
command! MarkdownRunnerInsert lua require("markdown_runner").insert()
command! MarkdownRunnerClearCache lua require("markdown_runner").clear_cache()

let g:loaded_markdown_runner = 1
