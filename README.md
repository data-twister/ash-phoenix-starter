# Ash Phoenix Application Starter Kit

![Unit Tests](https://github.com/data-twister/ash-phoenix-starter/actions/workflows/elixir.yaml/badge.svg)


A starter Kit that helps you build what's unique to your application faster. 

Don't reinvent the wheel for common features. Clone it, rename it and start shipping with confidence. 

Built for fast prototype and scaling in the future.

![Ash Phoenix Starter Kit](dashboard.png "Starter Kit Dashboard")

## FEATURES

1. Multitenancy with Team Management
2. Team switching
3. User invite to the team
4. Team user group permission management with Ash Policies
5. Permission management
6. Main Menu configurations
7. Chart Reports
8. Map Reports
11. Authentication with Ash Authentication
12. Templating with Daisy UI
14. Accounting with AshDouble Entry
15. Image Uploads (with multiple backends)

### On-going implementation

###### User Impersonation

1. Super user is added to the `super_users` list in the config/config.exs  
2. Super users can go to Settings > Users > and see Impersonate button
3. If clicked, super users access the application as if they are the user they are impersonating
4. Super Users can Go back to their account by clicking on top right menu and select "Go Back to My Account"

### Upcoming features

1. Email send out
2. AI integration with Ash AI
3. Paper trail with Ash Paper Trail
4. Workflows with ash_approver(A local package that needs to be published)
5. Self referencing data with AshParental
6. Documentations


## Installation 

1. Clone this repository or use it as a template for your new app
2. Run `mix rename AshPhoenixStarter MyNewProjectName` to rename your Phoenix App
3. Replace `AshPhoenixStarter` with `MyNewProjectName` everywhere else in the code base
4. Run `mix tailwind.install` to install tailwindcss
5. Confirm that all is well with `mix tests`
6. Start implementing your new features

## For map boundry jsons you can access them @https://datahub.io/core/geo-boundaries-us-110m or https://www.naturalearthdata.com/downloads/110m-cultural-vectors/ and export them to the corresponding json file


To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

### Phoenix
* https://www.phoenixframework.org/
* https://hexdocs.pm/phoenix/overview.html
* Forum: https://elixirforum.com/c/phoenix-forum

### Ash
* https://ash-hq.org/
* https://hexdocs.pm/ash/readme.html
* https://elixirforum.com/c/ash-framework-forum/
