{CompositeDisposable, Point, Range, TextBuffer} = require 'atom'

styleOk = (row) ->
  editor = atom.workspace.getActiveTextEditor()
  scope = editor.scopeDescriptorForBufferPosition([row,0])
  !scope.scopes.some (text) ->
    /^(markup.code|markup.raw|comment.block)/.test text

styleOk2 = (row) ->
  editor = atom.workspace.getActiveTextEditor()
  scope = editor.scopeDescriptorForBufferPosition([row,0])
  !scope.scopes.some (text) ->
    /^comment.block/.test(text)

module.exports = MarkdownFolder =
  subscriptions: null

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'markdown-folding:dwim-toggle': (event) => @dwimtoggle(event)
    @subscriptions.add atom.commands.add 'atom-workspace', 'markdown-folding:cycle': => @cycle()

  deactivate: ->
    @subscriptions.dispose()

  dwimtoggle: (event) ->
    editor = atom.workspace.getActiveTextEditor()
    row = editor.getCursorBufferPosition().row
    linetext = editor.lineTextForBufferRow(row)
    if linetext.match(/^(#+)/) && styleOk(row)
      @cycle()
    else if linetext.match(/^\s*```\w+/) && styleOk2(row)
      @togglefenced()
    else
      event.abortKeyBinding()

  lineIsHeader: (line_row_number) ->
    editor = atom.workspace.getActiveTextEditor()
    line_text = editor.lineTextForBufferRow(line_row_number)
    if line_text.substring(0, 1) == '#'
      return true
    else
      return false

  getCurrentHeaderLines: ->
    editor = atom.workspace.getActiveTextEditor()
    curr_line_row = editor.getCurrentParagraphBufferRange().start.row
    curr_line_text = editor.lineTextForBufferRow(curr_line_row)
    first_header_line_row = curr_line_row

    unless curr_line_text[0] == '#'
      throw new 'The current line is not a header'

    header_pounds = curr_line_text.match(/^#+/)[0]
    header_level = header_pounds.length

    last_header_line_row = -1
    for line_row in [curr_line_row + 1..editor.getLastBufferRow()]
      line_text = editor.lineTextForBufferRow(line_row)
      if line_text.substring(0, 1) == '#'
        line_header_pounds = line_text.match(/^#+/)[0]
        line_level = line_header_pounds.length
        if line_level <= header_level
          break
      last_header_line_row = line_row
    return [first_header_line_row, last_header_line_row]

  foldRows: (line_numbers) ->
    first_row = line_numbers[0]
    last_row = line_numbers[1]
    editor = atom.workspace.getActiveTextEditor()

    curr_pos = editor.getCursorBufferPosition()

    first_row_len = editor.buffer.lineLengthForRow(first_row)
    last_row_len = editor.buffer.lineLengthForRow(last_row)
    editor.setSelectedBufferRange(new Range(new Point(first_row, first_row_len), new Point(last_row, last_row_len)))
    editor.foldSelectedLines()

    editor.setCursorBufferPosition(curr_pos)

  unfoldRows: (line_numbers) ->
    editor = atom.workspace.getActiveTextEditor()
    first_row = line_numbers[0]
    last_row = line_numbers[1]
    for line_row in [first_row..last_row]
      editor.unfoldBufferRow(line_row)

  lineIsFolded: (line_row_number) ->
    editor = atom.workspace.getActiveTextEditor()
    return editor.isFoldedAtBufferRow(line_row_number)

  lineStartIsFolded: (line_row_number) ->
    editor = atom.workspace.getActiveTextEditor()
    if editor.screenPositionForBufferPosition([line_row_number, 0]).column == 0
      return false
    else
      return true

  getLineBeforeNextHeader: (line_row_number) ->
    editor = atom.workspace.getActiveTextEditor()
    for line_num in [line_row_number..editor.getLastBufferRow()]
      if @lineIsHeader(line_num)
        return line_num - 1
    return line_num - 1

  foldSubHeaders: (line_row_numbers) ->
    for line_row in [line_row_numbers[0]..line_row_numbers[1]]
      if @lineIsHeader(line_row)
        last_line = @getLineBeforeNextHeader(line_row + 1)
        @foldRows([line_row, last_line])

  cycle: ->
    curr_header_rows = @getCurrentHeaderLines()
    console.log 'caracola'
    if curr_header_rows[0] == -1
      throw new 'No header to fold'

    editor = atom.workspace.getActiveTextEditor()

    if editor.isFoldedAtBufferRow(curr_header_rows[0])
      curr_section_folded = true
    else
      curr_section_folded = false

    num_subheaders = 0
    num_folded_subheaders = 0
    num_hidden_subheaders = 0
    for line_row in [curr_header_rows[0] + 1..curr_header_rows[1]]
      if @lineIsHeader(line_row)
        num_subheaders++
        if @lineIsFolded(line_row)
          if @lineStartIsFolded(line_row)
            num_hidden_subheaders++
            # No need to count more
            break
          else
            num_folded_subheaders++

    if num_subheaders == 0
      if @lineIsFolded(curr_header_rows[0])
        @unfoldRows(curr_header_rows)
      else
        @foldRows(curr_header_rows)
    else
      # there are some subheaders
      if num_hidden_subheaders > 0
        @unfoldRows(curr_header_rows)
        @foldSubHeaders(curr_header_rows)
      else if num_folded_subheaders == 0
        @foldRows(curr_header_rows)
      else
        @unfoldRows(curr_header_rows)
