import { GithubClient } from "../github.ts";
import { selectComment, selectIssue } from "./utils.ts";

export class DeletePageAction {
  #client: GithubClient;

  constructor(client: GithubClient) {
    this.#client = client;
  }

  async Do() {
    const issues = await this.#client.listIssues();
    const selectedIssue = await selectIssue(issues);
    if (selectedIssue === undefined) {
      console.log("Book is not selected");
      return;
    }
    console.log("Selected book: ", selectedIssue.title);

    const comments = await this.#client.listIssueComments(
      selectedIssue.issue_number,
    );
    const selectedComment = await selectComment(comments);
    if (selectedComment === undefined) {
      console.log("Page is not deleted");
      return;
    }

    await this.#client.deleteIssueComment(selectedComment.comment_id);
    console.log("Page is deleted: ", selectedComment.title);
  }
}
