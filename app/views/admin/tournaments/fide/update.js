$("#dialog_updated_fide_data")
  .html("<%= j render('admin/tournaments/fide/updated_data') %>")
  .dialog("option", "title", "Updated FIDE Data")
  .dialog("open");
