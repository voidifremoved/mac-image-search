import Foundation

@MainActor
public final class AppEnvironment: ObservableObject {
    public let database: AppDatabase
    public let secretStore: SecretStoring
    public let folderRepo: WatchedFolderRepository
    public let assetRepo: ImageAssetRepository
    public let contentRepo: ImageContentRepository
    public let analysisRepo: ImageAnalysisRepository
    public let embeddingRepo: EmbeddingRepository
    public let jobRepo: IndexJobRepository
    public let searchRepo: SearchRepository
    public let folderAccessStore: FolderAccessStore
    public let thumbnailStore: ThumbnailStore
    public let vectorIndex: VectorIndexing
    public let embeddingService: EmbeddingService
    public let visionAnalyzer: VisionAnalyzer
    public let pipeline: IndexPipeline
    public let scheduler: JobScheduler
    public let coordinator: IndexCoordinator
    public let folderWatcher: FolderWatching
    @Published public var providerConfig: AIProviderConfiguration {
        didSet {
            providerConfig.saveToUserDefaults()
        }
    }

    public init(
        database: AppDatabase,
        secretStore: SecretStoring? = nil,
        providerConfig: AIProviderConfiguration? = nil,
        customVisionAnalyzer: VisionAnalyzer? = nil,
        customEmbeddingService: EmbeddingService? = nil
    ) {
        self.database = database
        let secrets = secretStore ?? KeychainStore()
        self.secretStore = secrets
        let config = providerConfig ?? AIProviderConfiguration.loadFromUserDefaults()
        self.providerConfig = config

        self.folderRepo = WatchedFolderRepository(database: database)
        self.assetRepo = ImageAssetRepository(database: database)
        self.contentRepo = ImageContentRepository(database: database)
        self.analysisRepo = ImageAnalysisRepository(database: database)
        self.embeddingRepo = EmbeddingRepository(database: database)
        self.jobRepo = IndexJobRepository(database: database)
        self.searchRepo = SearchRepository(database: database)

        let accessStore = FolderAccessStore(repository: self.folderRepo)
        self.folderAccessStore = accessStore
        self.thumbnailStore = ThumbnailStore()
        let vecIndex = ExactVectorIndex()
        self.vectorIndex = vecIndex

        let embService = customEmbeddingService ?? AppleSentenceEmbeddingService()
        self.embeddingService = embService

        let visAnalyzer = customVisionAnalyzer ?? OpenAICompatibleVisionClient(
            configuration: config,
            secretStore: secrets
        )
        self.visionAnalyzer = visAnalyzer

        let pipe = IndexPipeline(
            database: database,
            contentRepository: self.contentRepo,
            assetRepository: self.assetRepo,
            analysisRepository: self.analysisRepo,
            embeddingRepository: self.embeddingRepo,
            visionAnalyzer: visAnalyzer,
            embeddingService: embService,
            vectorIndex: vecIndex,
            providerConfig: config
        )
        self.pipeline = pipe

        let sched = JobScheduler(jobRepository: self.jobRepo)
        self.scheduler = sched

        self.coordinator = IndexCoordinator(
            database: database,
            folderAccessStore: accessStore,
            assetRepository: self.assetRepo,
            pipeline: pipe,
            scheduler: sched,
            vectorIndex: vecIndex,
            embeddingRepository: self.embeddingRepo,
            embeddingService: embService
        )

        self.folderWatcher = FolderWatcher()
    }

    public static func preview() -> AppEnvironment {
        let db = try! AppDatabase.inMemory()
        let secrets = InMemorySecretStore()
        try? secrets.setSecret("mock_key", forKey: AIProviderConfiguration.defaultAPIKeyIdentifier)
        return AppEnvironment(
            database: db,
            secretStore: secrets,
            customVisionAnalyzer: MockVisionAnalyzer()
        )
    }

    public var searchService: SearchService {
        SearchService(
            vectorIndex: vectorIndex,
            embeddingService: embeddingService,
            searchRepository: searchRepo,
            assetRepository: assetRepo,
            folderRepository: folderRepo,
            database: database
        )
    }
}
