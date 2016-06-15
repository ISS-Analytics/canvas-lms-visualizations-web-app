# Canvas LMS Class Visualizations Web App

This should be run in conjunction with the [API](https://github.com/ISS-Analytics/canvas-lms-visualizations-api).

Feel free to clone the repo.

### config_env.rb

To generate `MSG_KEY` and `DB_KEY` for the config_env, simply run `rake keys_for_config` from the terminal and copy the generated keys to config_env.rb.

### Gems & DB

To get up and running on localhost, run `rake` from the terminal.
- This will install the required gems and setup the database.
- The Rakefile has additional commands to help with deployment to heroku.
