# Step-by-step: Create a new Lambda in AWS

Use this to create the **payout-parse** Lambda (or any new Lambda). All steps are in the **AWS Console** in your browser.

---

## Part 1: Create the Lambda function

1. **Open AWS Console**  
   Go to [https://console.aws.amazon.com](https://console.aws.amazon.com) and sign in.

2. **Go to Lambda**  
   In the search bar at the top, type **Lambda** and click **Lambda** (under Services).

3. **Create function**  
   Click the orange **Create function** button.

4. **Choose “Author from scratch”**  
   (It’s usually selected by default.)

5. **Function name**  
   Enter: **superbowlbox-payout-parse**  
   (Or any name you like.)

6. **Runtime**  
   Choose **Node.js** and pick **Node.js 20.x** from the dropdown.

7. **Permissions**  
   Leave **Create a new role with basic Lambda permissions** (default).  
   That’s enough for this function.

8. **Create**  
   Click **Create function** at the bottom.  
   You’ll land on the function’s page.

---

## Part 2: Put your code in the Lambda

9. **Open the code editor**  
   In the middle of the page you’ll see **Code source** and a file like **index.mjs** or **index.js** in the file tree on the left.  
   Click that file.

10. **Delete the existing code**  
    Select all the code in the editor (e.g. Cmd+A) and delete it.

11. **Paste the Lambda code**  
    Open the file **`docs/lambda-payout-parse-index.js`** from this repo.  
    Copy **all** of its contents and paste into the Lambda editor.

12. **Save**  
    Click **Deploy** (or **Save**) so the new code is deployed.

---

## Part 3: Set environment variable and timeout

13. **Open Configuration**  
    Click the **Configuration** tab (next to Code).

14. **Environment variables**  
    - In the left sidebar, click **Environment variables**.  
    - Click **Edit**.  
    - Click **Add environment variable**.  
    - **Key:** `ANTHROPIC_API_KEY`  
    - **Value:** your Anthropic API key (same one you use for the grid Lambda).  
    - Click **Save**.

15. **Timeout**  
    - In the left sidebar, click **General configuration**.  
    - Click **Edit**.  
    - **Timeout:** set to **10** seconds (or 30 if you prefer).  
    - Click **Save**.

---

## Part 4: Add an HTTP trigger (API Gateway)

16. **Add trigger**  
    Go back to the **Code** tab.  
    Above the code area, click **Add trigger**.

17. **Choose API Gateway**  
    - **Select a source:** **API Gateway**.  
    - **API:** choose **Create a new API** (or **Create an HTTP API**).  
    - **API name** can stay default or be e.g. **superbowlbox-payout-api**.  
    - **Deployment stage:** e.g. **default** (or **prod**).  
    - **Security:** **Open** (for a simple POST from the app; you can lock it down later).  
    - Click **Add**.

18. **Get the URL**  
    After the trigger is added, in the **Configuration** tab → **Triggers**, you’ll see your API Gateway trigger.  
    Click the **API endpoint** link (or the trigger name).  
    You’ll see something like:  
    **https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/default**  
    Your **payout-parse URL** is that base + the **resource path** shown for the Lambda (often something like **/superbowlbox-payout-parse**).  
    So the full URL might be:  
    **https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse**  
    Copy that full URL.

---

## Part 5: Use it in the app

19. **Secrets.plist**  
    In your Xcode project, open **Secrets.plist** (or create it from **Secrets.example.plist**).

20. **Add the payout URL**  
    Add a new row:  
    - **Key:** `PayoutParseBackendURL`  
    - **Value:** the full URL you copied (e.g. `https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse`).

21. **Run the app**  
    Enter payout rules in the app and save (or tap Parse with AI). The app will call this Lambda; leader and earnings will use the parsed structure.

---

## Quick checklist

- [ ] Lambda created (Node.js 20.x)  
- [ ] Code from `lambda-payout-parse-index.js` pasted and deployed  
- [ ] Environment variable **ANTHROPIC_API_KEY** set  
- [ ] Timeout set to 10 (or 30) seconds  
- [ ] API Gateway trigger added (HTTP API)  
- [ ] Full invoke URL copied  
- [ ] **PayoutParseBackendURL** in Secrets.plist set to that URL  

---

## If you already have an API (e.g. for the grid)

If you already have an API Gateway that has your grid Lambda (e.g. **POST /ai-grid**):

1. In **API Gateway** in the console, open that API.  
2. Click **Routes** → **Create**.  
3. Method: **POST**.  
4. Path: **/parse-payout** (or **/payout-parse**).  
5. Integration: **Lambda**, then select **superbowlbox-payout-parse**.  
6. Your payout URL is: **your existing API base URL** + **/parse-payout**.  
   Example: `https://kcmpxvlwa8.execute-api.us-east-1.amazonaws.com/parse-payout`  
   (If your API has a stage like **default**, it might be `.../default/parse-payout` — use the URL shown in the console.)

Use that full URL as **PayoutParseBackendURL** in Secrets.plist.
