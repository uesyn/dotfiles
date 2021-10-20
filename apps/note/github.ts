import { Octokit } from "@octokit/core";

export class GithubClient {
  private client: Octokit;
  private repo: string;
  private user: string;

  constructor(token: string, user: string, repo: string) {
    this.client = new Octokit({
      auth: token,
    });
    this.repo = repo;
    this.user = user;
  }

  async listIssues() {
    const { data: data } = await this.client.request(
      "GET /repos/{owner}/{repo}/issues",
      {
        owner: this.user,
        repo: this.repo,
      },
    );
    return data;
  }

  async listIssueComments(issue_number: number) {
    const { data: data } = await this.client.request(
      "GET /repos/{owner}/{repo}/issues/{issue_number}/comments",
      {
        owner: this.user,
        repo: this.repo,
        issue_number: issue_number,
      },
    );
    return data;
  }

  async getIssueComment(comment_id: number) {
    const { data: data } = await this.client.request(
      "GET /repos/{owner}/{repo}/issues/comments/{comment_id}",
      {
        owner: this.user,
        repo: this.repo,
        comment_id: comment_id,
      },
    );
    return data;
  }

  async updateIssueComment(comment_id: number, body: string) {
    const { data: data } = await this.client.request(
      "PATCH /repos/{owner}/{repo}/issues/comments/{comment_id}",
      {
        owner: this.user,
        repo: this.repo,
        comment_id: comment_id,
        body: body,
      },
    );
    return data;
  }

  async createIssue(title: string, body: string) {
    if (title.length == 0) {
      throw new Error("title must not be empty");
    }

    if (body.length == 0) {
      throw new Error("body must not be empty");
    }

    const { data: data } = await this.client.request(
      "POST /repos/{owner}/{repo}/issues",
      {
        owner: this.user,
        repo: this.repo,
        title: title,
        body: body,
      },
    );
    return data;
  }

  async createIssueComment(issue_number: number, body: string) {
    if (body.length == 0) {
      throw new Error("body must not be empty");
    }
    body = body.replaceAll("\r\n", "\n").replaceAll("\n", "\r\n");

    const { data: data } = await this.client.request(
      "POST /repos/{owner}/{repo}/issues/{issue_number}/comments",
      {
        owner: this.user,
        repo: this.repo,
        issue_number: issue_number,
        body: body,
      },
    );
    return data;
  }

  async deleteIssueComment(comment_id: number) {
    return await this.client.request(
      "DELETE /repos/{owner}/{repo}/issues/comments/{comment_id}",
      {
        owner: this.user,
        repo: this.repo,
        comment_id: comment_id,
      },
    );
  }
}
