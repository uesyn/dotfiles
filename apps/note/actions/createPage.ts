import { GithubClient } from "../github.ts";
import { selectIssue } from "./utils.ts";

export class CreatePageAction {
  #client: GithubClient;

  constructor(client: GithubClient) {
    this.#client = client;
  }

  async Do() {
    const issues = await this.#client.listIssues();
    const selected = await selectIssue(issues);
    if (selected === undefined) {
      console.log("Book is not selected");
      return;
    }

    console.log("Selected book: ", selected.title);
    const title = prompt("Input Page title:");
    if (title === null || title.trim().length === 0) {
      throw new Error("title must not be emepty");
    }

    const body = "#" + " " + title;
    const comment = await this.#client.createIssueComment(
      selected.issue_number,
      body,
    );
    console.log("Page is created: " + comment.body);
  }
}
