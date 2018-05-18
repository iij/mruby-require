assert("Kernel.require") do
  # preparation
  $gvar1 = 0
  lvar1 = 0
  class MrubyRequireClass; end

  ret = Tempfile.open(["mruby-require-test", ".rb"]) { |f|
    f.write <<-PROGRAM
      # global variables
      $gvar0 = 1
      $gvar1 = 1

      # toplevel local variables
      lvar0 = 1
      lvar1 = 1

      # define a procedure
      def proc0
        :proc0
      end

      # define a new method of an existing class.
      class MrubyRequireClass
        def foo
          :foo
        end
      end
    PROGRAM
    f.flush

    require(f.path)
  }
  assert_true ret

  # Kernel.require can create a global variable
  assert_equal 1, $gvar0

  # Kernel.require can change value of a global variable
  assert_equal 1, $gvar1

  # Kernel.require cannot create a local variable
  assert_raise(NoMethodError) do
    lvar0
  end

  # Kernel.require cannot change value of a local variable
  assert_equal 0, lvar1

  # Kernel.require can define a toplevel procedure
  assert_equal :proc0, proc0

  # Kernel.require can add a method to an existing class
  assert_equal :foo, MrubyRequireClass.new.foo
end
