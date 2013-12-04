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

    # Toggle option if the parent is clicked
    $(".options .selected").on "click", (e)->
      $(this).hide()
      $(this).siblings(".choices").slideDown()

    # Show options when the selected option is clicked
    $(".options .choices .text_option").on "click", (e)->
      alert("clicked")
      input = $(".options .choices .text_option").first().children('input')
      console.log(input.is(":disabled"))
      unless input.is(":disabled")
        input.prop("checked", true)

    # Disable some options when no keyword is defined
    $(".field .textfield").on
      keyup: (e)->
        if $(this).val() == ""
          options = $(this).parents(".field").siblings(".options")
          contains = options.children(".text_option.contains")
          contains.children("input").prop("disabled", true)
          is_exactly = options.children(".text_option.is_exactly")
          is_exactly.children("input").prop("disabled", true)
          does_not_contain = options.children(".text_option.does_not_contain")
          does_not_contain.children("input").prop("disabled", true)
        else
          options = $(this).parents(".field").siblings(".options")
          contains = options.children(".text_option.contains")
          contains.children("input").prop("disabled", false)
          is_exactly = options.children(".text_option.is_exactly")
          is_exactly.children("input").prop("disabled", false)
          does_not_contain = options.children(".text_option.does_not_contain")
          does_not_contain.children("input").prop("disabled", false)