require 'puppet_x/jenkins'

module PuppetX::Jenkins::Util
  def unundef(data)
    iterate(data) { |x| x == :undef ? nil : x }
  end
  module_function :unundef

  def undefize(data)
    iterate(data) { |x| x.nil? ? :undef : x }
  end
  module_function :undefize

  # loosely based on
  # https://stackoverflow.com/questions/16412013/iterate-nested-hash-that-contains-hash-and-or-array
  def iterate(data, &block)
    return data unless block_given?

    case data
    when Hash
      h = Hash.new

      data.each do |(k,v)|
        h[k] = iterate(v, &block)
      end

      return h
    when Array
      data.collect { |v| iterate(v, &block) }
    else
      block.call data
    end
  end
  module_function :iterate
end
