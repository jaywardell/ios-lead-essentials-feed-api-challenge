//
//  Copyright © 2018 Essential Developer. All rights reserved.
//

import Foundation

public final class RemoteFeedLoader: FeedLoader {
	private let url: URL
	private let client: HTTPClient
	
	public enum Error: Swift.Error {
		case connectivity
		case invalidData
	}
	
	public init(url: URL, client: HTTPClient) {
		self.url = url
		self.client = client
	}
	
	public func load(completion: @escaping (FeedLoader.Result) -> Void) {
		client.get(from: url) { [weak self] result in
			guard let self = self else { return }
			completion(self.map(result))
		}
	}
	
	private enum StatusCode: Int {
		case OK = 200
		init?(_ int: Int) { self.init(rawValue: int) }
	}
	
	private func map(_ result: HTTPClient.Result) -> FeedLoader.Result {
		switch result {
		case .failure:
			return .failure(Error.connectivity)
		
		case let .success((data, response)):
			if .OK == StatusCode(response.statusCode),
			   let decoded = try? JSONDecoder().decode(Root.self, from: data) {
				let items = decoded.items.map {
					FeedImage(id: $0.image_id,
							  description: $0.image_desc,
							  location: $0.image_loc,
							  url: $0.image_url)
				}
				return .success(items)
			}
			
			return .failure(Error.invalidData)
		}
	}
	
	/*
	Remote Feed Image Spec:

	Property	Type
	image_id	UUID
	image_desc	String (optional)
	image_loc	String (optional)
	image_url	URL

	*/
	private struct RemoteFeedImage: Decodable {
		let image_id: UUID
		let image_desc: String?
		let image_loc: String?
		let image_url: URL
	}
	
	/*
	Payload contract:


	200 RESPONSE

	{
		"items": [
			{
				"image_id": "a UUID",
				"image_desc": "a description",
				"image_loc": "a location",
				"image_url": "https://a-image.url",
			},
			{
				"image_id": "another UUID",
				"image_desc": "another description",
				"image_url": "https://another-image.url"
			},
			{
				"image_id": "even another UUID",
				"image_loc": "even another location",
				"image_url": "https://even-another-image.url"
			},
			{
				"image_id": "yet another UUID",
				"image_url": "https://yet-another-image.url"
			}
			...
		]
	}

	*/
	private struct Root: Decodable {
		let items: [RemoteFeedImage]
	}
}
