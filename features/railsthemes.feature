Feature: Running railsthemes on the command-line
  As a RailsThemes customer
  In order to install my theme on the command-line
  I want to run the program and see output

  Scenario: Running without any parameters
    When I run `railsthemes`
    Then the output should contain:
    """
    Usage:
    """
