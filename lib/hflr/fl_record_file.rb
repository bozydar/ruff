class FLRFile

  include Enumerable

  attr_reader :line_number, :record_template

  def initialize(source, record_types, record_layouts, logical_first_column=0, extra_columns = nil)
    # Allow record layouts like 
    # {:type1=>[:var1=>1..5,:var2=>7..8],:type2=>[:var1=>1..1,:var2=>3..4]}
    if record_layouts.values.first.is_a? Hash
      record_layouts = create_layouts(record_layouts)
    end
    @line_number = 0
    @file = source
    @record_type_labels = record_types
    @record_type_symbols = record_types.is_a?(Hash) ? record_types : :none
    if extra_columns then
      @record_template = HFLR::RecordTemplate.create(record_layouts, @record_type_symbols, logical_first_column, extra_columns)
    else
      @record_template = HFLR::RecordTemplate.create(record_layouts, @record_type_symbols, logical_first_column)
    end
  end

  def set_fast
    @fast = !@record_type_labels.is_a?(Hash)
    unless @fast
      raise "Cannot set fast mode with more than one record type."
    end
    if @fast
      @width = get_record_width_from_file


      records_to_take = 100000000 / @width

      @buffer_size = @width * records_to_take


      @position=0
      @current_buffer=nil
    end
  end

  def ranges=(ranges)
    @fast or raise "Cannot read selected ranges because input file has multiple record types #{@record_type_labels.to_s}"
    unless ranges.first.is_a?(Range)
      raise "You specified a #{ranges.first.class.to_s} instead of a range in the list of ranges.  Use (a..b) to specify a range."
    end

    @offsets =offsets_to_read(ranges, @width)

    @ranges = ranges
  end


  def in_range?(line_number)
    @ranges ? !!(@ranges.detect { |r| r.member?(line_number) }) : true
  end

  def finished?
    if @fast
      @offsets.empty? && @current_buffer.nil?
    else
      @file.eof?
    end
  end

  def close
    @file.close
  end

# If multiple record types,  extract it from the string, otherwise just return the type of this file
  def get_record_type(line)
    return nil if line.nil?
    return nil if line.strip.empty?
    if @record_type_labels.is_a?(Hash)
      matching_pair = @record_type_labels.find do |_, value|
        discriminator = value[:discriminator]
        position = value[:position] - 1
        line[position..-1].start_with?(discriminator)
      end
      if matching_pair
        matching_pair[0]
      else
        nil
      end
    else
      @record_type_labels
    end
  end

  def build_record(line)
    return nil if line.nil?
    record_type = line_type(line)
    raise "Unknown record type at line #{@line_number.to_s}" if record_type == :unknown
    @record_template[record_type].build_record(line.chomp)
  end

  def next_record
    build_record(get_next_known_line_type)
  end

  def line_type(line)
    record_type = get_record_type(line)
    record_type ? record_type : :unknown
  end

  def get_next_known_line_type
    @fast ? fast_get_next_known_line_type : sequential_get_next_known_line_type
  end

  def get_next_line
    line = @file.gets
    @line_number+=1
    line
  end

  def next
    build_record(get_next_line)
  end

  def fast_get_next_known_line_type
    if @current_buffer.nil? && (@offsets.nil? || @offsets.empty?)
      nil
    else
      if @current_buffer.nil?
        chunk = @offsets.shift


        @file.pos = chunk.pos
        @current_buffer=@file.read(chunk.width)

        record= @current_buffer.slice(@position, @width)


        @position += @width

        if @position >= @current_buffer.size

          @current_buffer = nil
          @position=0
        end
        return record
      else
        record= @current_buffer.slice(@position, @width)

        @position += @width
        if @position>=@current_buffer.size
          @position=0
          @current_buffer=nil
        end
        return record
      end

    end
  end

  def sequential_get_next_known_line_type
    line = @file.gets
    @line_number+=1
    record_type = line_type(line)
    while !finished? && (!in_range?(@line_number) || record_type == :unknown)
      line = @file.gets
      @line_number+=1
      record_type = line_type(line)
    end
    record_type == :unknown ? nil : line
  end


  def each
    @line_number = 1
    if @fast
      yield(next_record) until finished?
    else
      @file.each_line do |line|
        unless line_type(line) == :unknown || !in_range?(@line_number)
          data = build_record(line)
          yield data
        end
      end
    end
  end

  # This will take a Hash or Struct orArray;  if an Array the record type must be the last element when
  # the record layout has more than one record type.
  def <<(record)
    record_type =
        if record.is_a? Array
          @record_type_symbols == :none ? @record_template.keys.first : record.last
        else
          if @record_template[record[:record_type]] == nil then
            raise "Record type problem in output: #{record[:record_type].to_s} type on record, #{@record_template.keys.join(",")} types of templates"
          end
          @record_type_symbols == :none ? @record_template.keys.first : record[:record_type]
        end
    line = @record_template[record_type].build_line(record)
    if @cr_before_line
      line = "\n" + line
    else
      @cr_before_line = true
    end
    @file.write(line)
  end

# Use when creating a new HFLR file
  def self.open(path, mode, record_types, record_layouts, logical_first_column=0)
    file = File.open(path, mode)
    begin
      hflr_file = new(file, record_types, record_layouts, logical_first_column)
      yield hflr_file
    ensure
      file.close
    end
  end

  private

  def offsets_to_read(ranges, width)
    #ranges.map{|r| r.map{|o| o * width}}.flatten.uniq
    chunk = Struct.new(:pos, :width)
    chunks = []
    ranges.each do |range|
      offsets = range.map { |offset| offset }
      taken = []

      until offsets.empty?
        taken << offsets.shift
        if taken.size * width == @buffer_size || offsets.empty?

          chunks << chunk.new(taken.first * @width, taken.size * width)
          taken = []
        end # if
      end # while
    end # each

    chunks
  end

  def get_record_width_from_file
    width = @file.gets.size
    @file.rewind
    width
  end


# If the layout is given in the convenient Ruby form
  def create_layouts(layout)
    var_class = Struct.new(:name, :start, :len)
    new_layout = {}
    layout.each_pair do |record_type, vars|

      new_layout[record_type] = []
      vars.each_pair do |var_name, range|
        new_layout[record_type] << var_class.new(var_name.to_s, range.first, range.last - range.first + 1)
      end
      new_layout[record_type].sort! { |a, b| a.start<=>b.start }
    end
    new_layout
  end

end

