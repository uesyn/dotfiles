import { GithubClient } from "../github.ts";

export class CreateBookAction {
  #client: GithubClient;

  constructor(client: GithubClient) {
    this.#client = client;
  }

  async Do() {
    const title = prompt("Input Book title:");
    if (title === null || title.trim().length === 0) {
      throw new Error("title must not be emepty");
    }
    const issue = await this.#client.createIssue(title, title);
    console.log("Book is created: " + issue.title);
  }
}
