# Activities

## Wednesday, September 10, 2025

- Troubleshooted issue with accessing the Nextcloud app via IP address.
- Verified that the Docker containers are running correctly.
- Checked the `trusted_domains` configuration in `config.php`.
- Confirmed that the app is accessible via `http://localhost:8080`.
- Identified the issue as a WSL networking problem.
- Recommended using `http://localhost:8080` for accessing the app.
- Assisted with configuring access from the Android client by:
    - Instructing the user to create a Windows Firewall rule.
    - Adding the Windows host IP address to the `trusted_domains` configuration.
    - Added the WSL vEthernet IP address to the `trusted_domains` configuration as an alternative.
    - Instructed the user to disable the Windows Firewall for the public profile for testing.
    - Recommended enabling the mirrored networking mode in WSL as a potential solution.

## Friday, September 12, 2025

- Created a `.gitignore` file and populated it with the right things to ignore.
