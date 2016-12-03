Feature: Checks That the site loads and can be tested
  As a developer
  I need to be able to tell if the site initialized and can be tested

  Scenario:  Check that site exists
    Given I am on "/"
    Then I should see "DockerDrop, a Docker Training Site"

  @api
  Scenario:  Check that an administrator can log in and see the site
    Given I am logged in as a user with the "administrator" role
    When I am on "/"
    Then I should see "DockerDrop, a Docker Training Site"
    And I should not see the link "Log in"

  @api @javascript
  Scenario:  Check that the site can be tested with Selenium
    Given I am logged in as a user with the "administrator" role
    When I am on "/"
    Then I should see "DockerDrop, a Docker Training Site"
    And I should not see the link "Log in"
