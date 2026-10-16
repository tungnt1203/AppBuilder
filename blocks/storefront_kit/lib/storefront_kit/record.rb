module StorefrontKit
  # What the API answered, as an object: product.title, variant.available?, cart.items. Every key
  # of the JSON reads as a method (with a ? for true/false ones), so a field the Platform adds
  # later is there without a new release; `one`/`many` give nested parts their own class.
  class Record
    def self.one(name, klass) = relation(name, :one, klass)
    def self.many(name, klass) = relation(name, :many, klass)
    def self.relations = (@relations ||= superclass.respond_to?(:relations) ? superclass.relations.dup : {})

    # Fields the API may leave out when they're empty: they read as nil instead of failing.
    def self.optional(*names)
      names.each { |name| define_method(name) { @data[name.to_s] } }
    end

    # A nested part reads even when the API left it out: nil for one, [] for many.
    def self.relation(name, kind, klass)
      relations[name.to_s] = [ kind, klass ]
      define_method(name) { read(name.to_s) }
    end

    def self.wrap(data)
      case data
      when nil then nil
      when Array then data.map { |item| wrap(item) }
      when self then data
      else new(data)
      end
    end

    def initialize(data = {})
      @data = (data || {}).to_h.transform_keys(&:to_s)
    end

    def [](key) = read(key.to_s)
    def key?(key) = @data.key?(key.to_s)
    def to_h = @data
    def as_json(*) = @data

    def ==(other) = other.class == self.class && other.to_h == to_h
    alias eql? ==
    def hash = [ self.class, @data ].hash

    def respond_to_missing?(name, include_private = false)
      @data.key?(name.to_s.delete_suffix("?")) || super
    end

    def method_missing(name, *args)
      key = name.to_s
      if args.empty? && key.end_with?("?") && @data.key?(key.delete_suffix("?"))
        @data[key.delete_suffix("?")] ? true : false
      elsif args.empty? && @data.key?(key)
        read(key)
      else
        super
      end
    end

    def inspect = "#<#{self.class.name} #{@data.inspect}>"

    private
      def read(key)
        @memo ||= {}
        return @memo[key] if @memo.key?(key)

        kind, klass = self.class.relations[key]
        value = @data[key]
        @memo[key] = if kind == :many then Array(value).map { |item| klass.new(item) }
        elsif kind == :one then (klass.new(value) if value)
        else value
        end
      end
  end
end
