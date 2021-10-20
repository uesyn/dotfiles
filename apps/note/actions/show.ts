import { GithubClient } from "../github.ts";
import { selectComment, selectIssue } from "./utils.ts";
import { renderMarkdown } from "charmd";

export class ShowAction {
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

    const comments = await this.#client.listIssueComments(
      selectedIssue.issue_number,
    );
    const selectedComment = await selectComment(comments);
    if (selectedComment === undefined) {
      console.log("Page is not selected");
      return;
    }

    const comment = await this.#client.getIssueComment(
      selectedComment.comment_id,
    );
    console.log(renderMarkdown(comment.body ?? ""));
  }
}
