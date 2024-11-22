class Frame
  attr_reader :function

  def initialize(function, args)
    @function = function
    @local_vals = args + @function.create_local_variables
  end

  def reference_local_var(local_index)
    raise "Invalid local index" if local_index >= @local_vals.size

    @local_vals[local_index]
  end
end
