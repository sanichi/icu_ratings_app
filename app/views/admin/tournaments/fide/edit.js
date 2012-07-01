$("#dialog_update_fide_data")
  .html("<%= j render('admin/tournaments/fide/update_data') %>")
  .dialog("option", "title", "Update FIDE Data")
  .dialog("open");
