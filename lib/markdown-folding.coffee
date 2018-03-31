{CompositeDisposable, Point, Range, TextBuffer} = require 'atom'

MAX_HEADER_CYCLE_FOLD_DEPTH = 4

module.exports = MarkdownFolder =
  subscriptions: null

  activate: (state) ->

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'markdown-folding:cycle': (event) => @cycle(event)
    @subscriptions.add atom.commands.add 'atom-workspace', 'markdown-folding:foldall-h1': => @foldall_h1()
    @subscriptions.add atom.commands.add 'atom-workspace', 'markdown-folding:foldall-h2': => @foldall_h2()

  deactivate: ->
    @subscriptions.dispose()

  cycle: (event) ->
    if (typeof event == 'undefined')
      @do_cycle

    editor = atom.workspace.getActiveTextEditor()
    row = editor.getCursorBufferPosition().row
    linetext = editor.lineTextForBufferRow(row)
    if linetext.match(/^(#+)/)
      @do_cycle()
    else
      event.abortKeyBinding()

  lineIsHeader: (line_row_number) ->
    editor = atom.workspace.getActiveTextEditor()
    line_text = editor.lineTextForBufferRow(line_row_number)
    if line_text.substring(0, 1) == '#'
      return true
    else
      return false


  getLineHeaderLevel: (line_text, max_header_depth=0) ->
    if line_text[0] != '#'
      return 0

    header_pounds = line_text.match(/^#+/)[0]
    header_level = header_pounds.length

    if max_header_depth > 0 && header_level > max_header_depth
      return 0

    return header_level

  getCurrentBlockRange: ->
    editor = atom.workspace.getActiveTextEditor()
    curr_line_row = editor.getCursorBufferPosition().row
    curr_line_text = editor.lineTextForBufferRow(curr_line_row)
    first_header_line_row = curr_line_row

    header_level = @getLineHeaderLevel(curr_line_text)
    if header_level == 0
      throw new 'The current line is not a header'

    last_header_line_row = -1
    for line_row in [curr_line_row + 1..editor.getLastBufferRow()]
      line_text = editor.lineTextForBufferRow(line_row)
      line_level = @getLineHeaderLevel(line_text)
      if line_level > 0 && line_level <= header_level
        break
      last_header_line_row = line_row
    return {'first_row_number': first_header_line_row, 'last_row_number': last_header_line_row - 1}


  foldBlock: (line_numbers) ->
    first_row = line_numbers['first_row_number']
    last_row = line_numbers['last_row_number']
    editor = atom.workspace.getActiveTextEditor()

    curr_pos = editor.getCursorBufferPosition()

    first_row_len = editor.buffer.lineLengthForRow(first_row)
    last_row_len = editor.buffer.lineLengthForRow(last_row)
    editor.setSelectedBufferRange(new Range(new Point(first_row, first_row_len), new Point(last_row, last_row_len)))
    editor.foldSelectedLines()

    editor.setCursorBufferPosition(curr_pos)


  foldToGivenHeaderLevelInBlock: (header_level, line_numbers) ->
    console.log('folding to header level', header_level)
    editor = atom.workspace.getActiveTextEditor()

    first_block_line = line_numbers['first_row_number']
    last_block_line = line_numbers['last_row_number']
    subblocks_to_fold = []
    for line_row in [first_block_line..last_block_line]
      line_text = editor.lineTextForBufferRow(line_row)
      if @lineIsHeader(line_row) && @getLineHeaderLevel(line_text) == header_level
        last_line = @getLineBeforeNextHeaderWithGivenLevel(line_row + 1, last_block_line, header_level)
        subblock = {'first_row_number': line_row, 'last_row_number': last_line}
        subblocks_to_fold.push(subblock)

    for subblock_to_fold in subblocks_to_fold

      @foldBlock(subblock_to_fold)


  unfoldBlock: (line_numbers) ->
    editor = atom.workspace.getActiveTextEditor()
    first_row = line_numbers['first_row_number']
    last_row = line_numbers['last_row_number']
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


  getLineBeforeNextHeaderWithGivenLevel: (first_line_number, last_line_number, header_level) ->
    editor = atom.workspace.getActiveTextEditor()
    for line_num in [first_line_number..last_line_number]
      line_text = editor.lineTextForBufferRow(line_num)
      current_line_level = @getLineHeaderLevel(line_text)
      if current_line_level > 0 && current_line_level <= header_level
        return line_num - 1
    return last_line_number


  do_cycle: ->
    console.log('doing cycle')
    editor = atom.workspace.getActiveTextEditor()
    curr_line_row = editor.getCursorBufferPosition().row
    curr_line_text = editor.lineTextForBufferRow(curr_line_row)
    first_header_line_row = curr_line_row

    current_block_header_level = @getLineHeaderLevel(curr_line_text)
    if current_block_header_level == 0
      # this is not a header, nothing to do
      return

    curr_header_rows = @getCurrentBlockRange()

    console.log(curr_header_rows)

    editor = atom.workspace.getActiveTextEditor()

    if editor.isFoldedAtBufferRow(curr_header_rows['first_row_number'])
      current_block_is_folded = true
    else
      current_block_is_folded = false

    console.log('folded', current_block_is_folded)
    if current_block_is_folded
      @unfoldBlock(curr_header_rows)
    else

      lowest_header_level_unfolded = undefined
      lowest_header_sublevel = undefined
      for line_row in [curr_header_rows['first_row_number'] + 1..curr_header_rows['last_row_number']]
        line_text = editor.lineTextForBufferRow(line_row)
        header_level = @getLineHeaderLevel(line_text)

        if header_level > current_block_header_level
          if lowest_header_sublevel == undefined || lowest_header_sublevel > header_level
            lowest_header_sublevel = header_level

        if !@lineStartIsFolded(line_row)
          # this line is not hidden
            if @lineIsFolded(line_row)
              continue

        if header_level <= current_block_header_level || header_level > MAX_HEADER_CYCLE_FOLD_DEPTH
          continue
        if lowest_header_level_unfolded == undefined || lowest_header_level_unfolded > header_level
          lowest_header_level_unfolded = header_level
        if header_level == current_block_header_level + 1
          break

      if lowest_header_level_unfolded != undefined && lowest_header_sublevel == lowest_header_level_unfolded
        @foldToGivenHeaderLevelInBlock(lowest_header_level_unfolded, curr_header_rows)
      else
        @foldBlock(curr_header_rows)


  foldall_h1: ->
    editor = atom.workspace.getActiveTextEditor()
    last_buffer_line = editor.getLastBufferRow()
    buffer_rows = {'first_row_number': 0,
    'last_row_number': last_buffer_line}
    @foldToGivenHeaderLevelInBlock(1, buffer_rows)


  foldall_h2: ->
    editor = atom.workspace.getActiveTextEditor()
    last_buffer_line = editor.getLastBufferRow()
    buffer_rows = {'first_row_number': 0,
    'last_row_number': last_buffer_line}
    @foldToGivenHeaderLevelInBlock(2, buffer_rows)
