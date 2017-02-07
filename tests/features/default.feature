Feature: Test Site is up
  In order to demonstrate that the site is running
  As a tester
  I need to be able to visit the home page and make sure the site is up

  Scenario:  Test that the site is up and running using Goette
    Given I visit "/"
    Then I should get a "200" HTTP response

  Scenario: Test the ability to find our site name in the header region using Goette
    Given I am on the homepage
    Then I should see "DockerDrop, a Docker Training Site" in the "header" region

  @api
  Scenario:  Test that the site is up and running using Goette and the api
    Given I am logged in as a user with the "administrator" role
    When I visit "/"
    Then I should get a "200" HTTP response

  @api
  Scenario: Test the ability to find our site name in the header region using Goett and the api
    Given I am logged in as a user with the "administrator" role
    When I am on the homepage
    Then I should see "DockerDrop, a Docker Training Site" in the "header" region

  @api @javascript
  Scenario:  Test that javascript is working
    Given I am logged in as a user with the "administrator" role
    When I visit "/user"
    Then I should see the link "View" in the "content" region

  @javascript
  Scenario:  Check Mailhog interface
    When I visit "/user/password"
    And I fill in "Username or email address" with "admin@example.com"
    And I press the "Submit" button
    Then I should see the success message containing "Further instructions have been sent to your email address"
    And I visit "http://mailhog:8025"
    And I wait for AJAX to finish
    Then I should see "Replacement login information for admin at DockerDrop, a Docker Training Site" in the "mail content" region


