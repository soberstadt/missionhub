$ ->
  $(document).ready ->

    $(document).on "click", ".side-search-option .toggler", (e)->
      fields = $(this).siblings(".fields")
      if fields.is(":visible")
        fields.slideUp("fast")
        $(this).removeClass("active")
      else
        fields.slideDown("fast")
        $(this).addClass("active")

    $(document).on "click", ".side-search-option .title", (e)->
      $(this).siblings(".toggler").click()

    $(document).on "click", ".side-search .side-search-toggler", (e)->
      toggler= $(this)
      fields = toggler.siblings(".side-search-options")
      if fields.is(":visible")
        toggler.removeClass("active")
        fields.slideUp "fast"
      else
        toggler.addClass("active")
        fields.slideDown "fast"

    # Reset survey filter
    $(".side-search-option .reset_filter").on "click", (e)->
      e.preventDefault()
      parent = $(this).parents(".side-search-option")
      type = parent.data("type")
      value = parent.data("value")
      option = parent.data("option")

      if type == "TextField"
        field = parent.find(".field input")
        actions = $(this).parents(".actions")
        options = actions.siblings(".options")
        field.val(value)
        options.find(".text_option." + option + " input").prop("checked", true)
        options.find(".choices").slideUp()
        options.find(".selected").show()
        field.keyup()
        actions.hide()




    # Toggle option if the parent is clicked
    $(".options .selected").on "click", (e)->
      $(this).hide()
      $(this).siblings(".choices").slideDown()

    # Show options when the selected option is clicked
    $(".options .choices .text_option").on "click", (e)->
      input = $(this).children('input')
      unless input.is(":disabled")
        input.prop("checked", true)

        # Show apply button
        apply = $(this).parents(".options").siblings(".actions")
        apply.show()

    # Disable some options when no keyword is defined
    $(".field .textfield").on
      keyup: (e)->
        options = $(this).parents(".field").siblings(".options")
        contains = options.children(".choices").children(".text_option.contains").children("input")
        is_exactly = options.children(".choices").children(".text_option.is_exactly").children("input")
        does_not_contain = options.children(".choices").children(".text_option.does_not_contain").children("input")
        is_blank = options.children(".choices").children(".text_option.is_blank").children("input")
        is_not_blank= options.children(".choices").children(".text_option.is_not_blank").children("input")

        # Show apply button
        apply = $(this).parents(".field").siblings(".actions")
        apply.show()

        if $(this).val() == ""
          if contains.is(":checked") || is_exactly.is(":checked") || does_not_contain.is(":checked")
            is_blank.prop("checked", true)
          contains.prop("disabled", true)
          is_exactly.prop("disabled", true)
          does_not_contain.prop("disabled", true)
        else
          if is_blank .is(":checked") || is_not_blank.is(":checked")
            contains .prop("checked", true)
          contains.prop("disabled", false)
          is_exactly.prop("disabled", false)
          does_not_contain.prop("disabled", false)