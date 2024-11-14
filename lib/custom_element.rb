# base class for creating custom elements
class CustomElement
  JS.eval("_ruby_custom_element_id = 0; _ruby_custom_element_this = {}; _attribute_changed = {}")

  def self.define(tag_name, element_class)
    JS.eval("customElements.define('#{tag_name}', #{element_class.name})")
  end

  def self.observed_attributes=(attrs)
    @observed_attributes = attrs
  end

  def self.observed_attributes
    @observed_attributes ||= []
  end

  def self.inherited(subclass)
    super
    subclass.define_singleton_method(:method_added){|_| __setup__}
  end

  def self.__setup__
    return if @setup_completed
    @setup_completed = true

    subclass = self
    superclass = subclass.superclass == CustomElement ? 'HTMLElement' : subclass.superclass.name.gsub(/::/, '__')
    class_name = subclass.name.gsub(/::/, '__')
    js = <<~JS
      #{class_name} = class extends #{superclass} {
        constructor() {
          super()
          if (this.constructor === #{class_name}) {
            this._ruby_custom_element_id = ++_ruby_custom_element_id
            _ruby_custom_element_this[this._ruby_custom_element_id] = this
            setTimeout(()=>{
              this._ruby_object_id = rubyVM.eval('#{subclass.name}.construct('+this._ruby_custom_element_id+').__id__').toJS()
              delete _ruby_custom_element_this[this._ruby_custom_element_id]
            }, 0)
          }
        }
        static get observedAttributes() {
          return rubyVM.eval('#{subclass.name}.observed_attributes').toJS()
        }
        connectedCallback() {
          setTimeout(()=>{rubyVM.eval('ObjectSpace._id2ref('+this._ruby_object_id+').connected_callback')}, 0)
        }
        disconnectedCallback() {
          setTimeout(()=>{rubyVM.eval('ObjectSpace._id2ref('+this._ruby_object_id+').disconnected_callback')}, 0)
        }
        adoptedCallback() {
          setTimeout(()=>{rubyVM.eval('ObjectSpace._id2ref('+this._ruby_object_id+').adopted_callback')}, 0)
        }
        attributeChangedCallback(name, oldValue, newValue) {
          var intervalID = setInterval(()=>{
            if (this._ruby_object_id) {
              _attribute_changed[this._ruby_object_id] = {name, oldValue, newValue}
              setTimeout(()=>{rubyVM.eval('x=ObjectSpace._id2ref('+this._ruby_object_id+');x.attribute_changed_callback(*JSrb.global[:_attribute_changed].to_h[x.__id__.to_s].to_h.values_at("name", "oldValue", "newValue"))')}, 0)
              clearInterval(intervalID)
            }
          }, 100)
        }
      }
    JS
    JS.eval(js)
  rescue JS::Error => e
    p e
    raise
  end

  def self.object
    @object ||= {}
  end

  def self.construct(id)
    obj = self.allocate
    obj.instance_variable_set(:@this, JSrb.global[:_ruby_custom_element_this][id])
    object[id] = obj
    obj.__send__ :initialize
    obj
  end

  def connected_callback
    # nothing
  end

  def disconnected_callback
    # nothing
  end

  def adopted_callback
    # nothing
  end

  def attribute_changed_callback(name, old_value, new_value)
    # nothing
  end

  def method_missing(...)
    @this.__send__(...)
  end

  def respond_to_missing?(name)
    !!@this[name]
  end
end
