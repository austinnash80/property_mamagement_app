# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn
]

# Family App: the part of an entry that matters (a door code, a password, a
# health detail) and the private scratchpad stay out of the logs. Titles still
# show, so a log line says which entry was saved without saying what it holds.
Rails.application.config.filter_parameters += %w[
  family_reference.value  family_reference.notes
  family_andie_entry.value family_andie_entry.notes
  family_rae_entry.value  family_rae_entry.notes
  family_note.title       family_note.body
]
