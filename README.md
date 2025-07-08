# SFDC DevOps Toolkit for PowerShell

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg) ![Salesforce CLI](https://img.shields.io/badge/sf-CLI-blue) ![License](https://img.shields.io/badge/License-MIT-green.svg)

A professional-grade, interactive PowerShell script designed to streamline Salesforce development and DevOps workflows. This toolkit provides a powerful command-line UI for managing orgs, comparing metadata, generating reports, and performing advanced deployments, all from a self-contained and portable project folder.

This tool was created in collaboration with Amit Bhardwaj.

---

## 🎯 Key Features

This all-in-one toolkit provides a rich set of features designed for Salesforce administrators, developers, and architects:

* **Self-Contained Project Structure:** No global dependencies or hidden files. Each project is a self-contained folder you can move, share, or place under version control.
* **Interactive Menu:** A user-friendly, color-coded menu system makes all features easily accessible.
* **Dual Org Management:** Select and work with both a **Source** and **Destination** org simultaneously. The script tracks their aliases and API versions independently.
* **Advanced Org Comparison:**
    * **Multiple Comparison Modes:** Choose between a quick comparison based on the source org's metadata, a comprehensive full comparison by merging metadata from both orgs, or a custom comparison using your own `package.xml`.
    * **CSV Change Report:** Automatically generates a `comparison_report.csv` file detailing every component that is **Changed**, **Added**, or **Removed**.
    * **Visual Diff:** Opens the retrieved metadata from both orgs directly in VS Code for a side-by-side visual comparison.
* **Powerful Manifest Generation:**
    * Generate a **full `package.xml`** from either the source or destination org.
    * Interactively build a **custom `package.xml`** by selecting metadata types from a list fetched live from the org.
* **Advanced Deployment Engine:**
    * A guided workflow for safe deployments.
    * Support for **destructive changes** (`destructiveChanges.xml`).
    * Option to run Apex tests and specify test levels.
    * Helper to **activate new flows** automatically after a successful deployment.
* **Auditing and Reporting:**
    * **Export Org Inventory:** Generate a complete CSV list of every metadata component in an org.
* **User Management Utility:**
    * Quickly **assign or un-assign permission sets** to any user via an interactive menu.
* **System Awareness:**
    * Checks for prerequisites like the Salesforce CLI.
    * Intelligently fetches and displays API versions for your connected orgs.

---

## ⚙️ Prerequisites

Before using the script, ensure you have the following installed on your Windows machine:

1.  **PowerShell 5.1** or higher (This is standard on Windows 10 and 11).
2.  **Salesforce CLI (`sf`)**.
3.  **Git**.
4.  **Visual Studio Code** (with the `code` command available in your system's PATH).

---

## 🚀 How to Use

The script is designed to be fully portable. Each project lives in its own folder.

#### 1. Download the Script
Download the `sfdc-toolkit.ps1` file into a convenient location.

#### 2. Create and Initialize Your First Project
The script operates on a "project per folder" basis.

1.  Create a new folder for your project (e.g., `C:\Dev\My-SF-Project`).
2.  Copy the `sfdc-toolkit.ps1` script into this new folder.
3.  Open a PowerShell terminal and navigate into your project folder:
    ```powershell
    cd C:\Dev\My-SF-Project
    ```
4.  Run the script:
    ```powershell
    .\sfdc-toolkit.ps1
    ```
5.  On the first run, the script will detect that no project exists and will ask to initialize the folder. Type `y` and press Enter.

    > This will create a hidden `.sfdc-toolkit` subfolder to store all your project settings and logs locally.

#### 3. Basic Workflow
Once the script is running, follow the menu prompts:

1.  **Authorize Orgs (Option 1):** The first step is to authorize the Salesforce orgs you want to work with. The script will open a browser for you to log in.
2.  **Select Orgs (Option 2):** Select your **Source** and **Destination** orgs from the list of authorized orgs. Their details and API versions will now appear in the header.
3.  **Compare Orgs (Option 7):**
    * Choose the "Quick Compare" or "Full Compare" option to automatically generate manifests and retrieve metadata.
    * After the process completes, a `comparison_report.csv` will be created in your project folder, and VS Code will open with a visual diff of the two orgs.
4.  **Deploy Changes (Option 9):** Use the advanced deployment feature to push changes from your source org's retrieved files to your destination org, with options for running tests and handling destructive changes.

---

## 🏗️ Architecture

* **Portable by Design:** All configuration, logs, and retrieved metadata are stored within your main project folder. There are no global dependencies or settings stored elsewhere on your machine. You can copy, move, or add the entire folder to a Git repository.
* **Self-Contained Org Projects:** When you work with an org (e.g., "CA_DEV"), the script creates a subfolder (`.\CA_DEV\`) and treats it as a mini, self-contained SFDX project. This ensures that CLI commands have the correct context and prevents any conflicts between orgs.
* **Local Caching:** The script caches the list of authorized orgs and metadata types within the `.sfdc-toolkit\settings.json` file to speed up subsequent operations. This cache can be cleared at any time from the main menu.

---

## 📄 License

This project is licensed under the MIT License.
