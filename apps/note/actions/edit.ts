import { GithubClient } from "../github.ts";
import { getEditorCommand, selectComment, selectIssue } from "./utils.ts";
import { crypto } from "std/crypto";

export class EditAction {
  #client: GithubClient;
  #decoder: TextDecoder;
  #disposed: boolean;

  constructor(client: GithubClient) {
    this.#client = client;
    this.#decoder = new TextDecoder();
    this.#disposed = false;
  }

  async Do() {
    const issues = await this.#client.listIssues();
    const selectedIssue = await selectIssue(issues);
    if (selectedIssue === undefined) {
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

    const bodyData = new TextEncoder().encode(
      (comment.body ?? "").replaceAll("\r\n", "\n"),
    );
    const tmpDir = await Deno.makeTempDir();
    const tmpFilename = await Deno.makeTempFile({
      prefix: tmpDir + "/",
      suffix: ".md",
    });
    await Deno.writeFile(tmpFilename, bodyData);

    const command = getEditorCommand();
    command.push(tmpFilename);
    const editor = Deno.run({
      cmd: command,
    });

    editor.status().then(() => {
      this.#disposed = true;
    });

    this.#updateCommentLoop(
      selectedComment.comment_id,
      tmpFilename,
      "",
    ).then(() => Promise.all([Deno.remove(tmpFilename), Deno.remove(tmpDir)]));
  }

  async #updateCommentLoop(
    commentId: number,
    editFilename: string,
    beforeFileHash: string,
  ): Promise<void> {
    const fileContents = await Deno.readFile(editFilename);
    const hash = new Uint8Array(
      await crypto.subtle.digest("SHA3-512", fileContents),
    ).toString();

    if (beforeFileHash.length === 0) {
      beforeFileHash = hash;
    }

    if (hash !== beforeFileHash) {
      await this.#client.updateIssueComment(
        commentId,
        this.#decoder.decode(fileContents),
      );
    }

    if (this.#disposed) {
      return Promise.resolve();
    }

    // Skip to next event loop.
    await new Promise<void>((resolve) => setTimeout(resolve, 100));
    await this.#updateCommentLoop(commentId, editFilename, hash);
  }
}
